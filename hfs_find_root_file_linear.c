/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

/*
 * Búsqueda lineal en el directorio raíz HFS+
 * Ajusta los tipos (HFSPlusCatalogKey, HFSPlusCatalogFile, etc.)
 * a tus propios typedefs/structs de payload_hfsplus_boot.c
 */

static int hfs_find_root_file_linear(struct hfs_volume *v,
                                     const char *target_name,
                                     HFSPlusCatalogFile *outFile)
{
    const uint32_t firstLeaf = v->catHeader.firstLeafNode;   // suele ser 1
    const uint32_t lastLeaf  = v->catHeader.lastLeafNode;    // suele ser 1

    for (uint32_t node = firstLeaf; node <= lastLeaf; ++node) {
        uint8_t *buf = v->catNodeBuf;  // o el buffer que ya usas en dump_root/debug_cat

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
            (void)keyLen; // si tu compilador se queja, úsalo o quita esta línea

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

            uint8_t *recData = rec + 2 + keyLen; // saltar keyLength (2B) + key
            uint16_t recType = be16toh(*(uint16_t *)recData);

            if (parentID == 2 &&
                recType == kHFSPlusFileRecord &&
                strcmp(nameAscii, target_name) == 0)
            {
                HFSPlusCatalogFile *fileRec = (HFSPlusCatalogFile *)recData;
                *outFile = *fileRec; // o memcpy(outFile, fileRec, sizeof(*outFile));

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

/*
 * Ejemplo de uso en tu código de arranque:
 *
 *   HFSPlusCatalogFile kfile;
 *   if (hfs_find_root_file_linear(&vol, "kernel.elf", &kfile) != 0) {
 *       printf("[boot] fallo leyendo kernel (no se encontró en root): kernel.elf\n");
 *       return -1;
 *   }
 *
 *   HFSPlusForkData *df = &kfile.dataFork;
 *   if (fork_read(&vol, df, 0, buffer, size) != 0) {
 *       printf("[boot] fallo leyendo datos de kernel.elf\n");
 *       return -1;
 *   }
 */
