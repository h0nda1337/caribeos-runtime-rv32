#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

F="payload_hfsplus_boot.c"
if [ ! -f "$F" ]; then
  echo "[x] No se encontró $F en $(pwd)"
  exit 1
fi

echo "[patch] Normalizando BOM/CRLF en $F..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' "$F" 2>/dev/null || true

if grep -q "hfs_find_root_file_linear" "$F"; then
  echo "[patch] hfs_find_root_file_linear ya existe, no lo vuelvo a insertar."
else
  echo "[patch] Inyectando hfs_find_root_file_linear al final de $F..."
  cat >> "$F" << 'EOF_HELPER'

/* ======================================================================== */
/*  Búsqueda lineal en el directorio raíz para un archivo por nombre        */
/*  hfs_find_root_file_linear()                                             */
/* ======================================================================== */

/*
 * OJO:
 * - Ajusta los nombres de tipos si en tu código se llaman distinto:
 *     - struct hfs_volume          -> el que ya uses (volumen HFS+)
 *     - HFSPlusCatalogKey          -> tu struct de clave de catálogo
 *     - HFSPlusCatalogFile         -> tu struct de archivo de catálogo
 *     - BTNodeDescriptor           -> descriptor de nodo BTree
 * - Esta versión asume:
 *     v->catHeader, v->catNodeBuf, v->nodeSize, cat_read_node()
 *     kBTLeafNode, kHFSPlusFileRecord, be16toh/be32toh/be64toh, etc.
 */

static int hfs_find_root_file_linear(struct hfs_volume *v,
                                     const char *target_name,
                                     HFSPlusCatalogFile *outFile)
{
    const uint32_t firstLeaf = v->catHeader.firstLeafNode;
    const uint32_t lastLeaf  = v->catHeader.lastLeafNode;

    for (uint32_t node = firstLeaf; node <= lastLeaf; ++node) {
        uint8_t *buf = v->catNodeBuf;

        if (cat_read_node(v, node, buf) != 0) {
            printf("[hfs+] error leyendo nodo cat #%u\n", node);
            return -1;
        }

        BTNodeDescriptor *nd = (BTNodeDescriptor *)buf;
        if (nd->kind != kBTLeafNode) {
            continue;
        }

        uint16_t *offsets = (uint16_t *)(buf + v->nodeSize);
        int numRecords = be16toh(nd->numRecords);

        for (int i = 0; i < numRecords; ++i) {
            uint16_t recOffset = be16toh(offsets[-1 - i]);
            uint8_t *rec = buf + recOffset;

            HFSPlusCatalogKey *key = (HFSPlusCatalogKey *)rec;
            uint16_t keyLen = be16toh(key->keyLength);
            (void)keyLen; // evita warning si no lo usas

            uint32_t parentID = be32toh(key->parentID);

            int nameLen = be16toh(key->nodeName.length);
            const uint16_t *uni = key->nodeName.unicode;

            char nameAscii[256];
            int j;
            for (j = 0; j < nameLen && j < 255; ++j) {
                uint16_t ch = be16toh(uni[j]);
                nameAscii[j] = (ch < 128) ? (char)ch : '?';
            }
            nameAscii[j] = '\0';

            uint8_t *recData = rec + 2 + keyLen;
            uint16_t recType = be16toh(*(uint16_t *)recData);

            if (parentID == 2 &&
                recType == kHFSPlusFileRecord &&
                strcmp(nameAscii, target_name) == 0)
            {
                HFSPlusCatalogFile *fileRec = (HFSPlusCatalogFile *)recData;
                *outFile = *fileRec;

                printf("[hfs+] encontrado '%s' CNID=%u size=%llu blocks=%u\n",
                       nameAscii,
                       (unsigned)be32toh(fileRec->fileID),
                       (unsigned long long)be64toh(fileRec->dataFork.logicalSize),
                       (unsigned)be32toh(fileRec->dataFork.totalBlocks));

                return 0;
            }
        }
    }

    printf("[hfs+] root: archivo '%s' no encontrado\n", target_name);
    return -1;
}

/* Fin de hfs_find_root_file_linear()                                       */
/* ======================================================================== */

EOF_HELPER

  echo "[patch] Función añadida al final de $F."
fi

echo
echo "=============================================================="
echo "Ejemplo de uso (ADÁPTALO dentro de payload_hfsplus_boot.c):"
echo "=============================================================="
cat << 'EOF_HINT'
    // Dentro de tu rutina de arranque, ya con 'vol' montado:

    HFSPlusCatalogFile kfile;

    if (hfs_find_root_file_linear(&vol, "kernel.elf", &kfile) != 0) {
        printf("[boot] fallo leyendo kernel (no se encontró en root): kernel.elf\n");
        return -1;
    }

    HFSPlusForkData *df = &kfile.dataFork;
    if (fork_read(&vol, df, 0, kernel_buf, kernel_size) != 0) {
        printf("[boot] fallo leyendo datos de kernel.elf\n");
        return -1;
    }

    // A partir de aquí ya tienes cargado kernel.elf en kernel_buf
EOF_HINT

echo
echo "[patch] Ahora abre payload_hfsplus_boot.c y sustituye la lógica vieja"
echo "        de búsqueda de mach_kernel/kernel por esta llamada de ejemplo."
