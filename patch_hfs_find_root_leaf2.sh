#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_find_root_leaf2] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_find_root_leaf2] reescribiendo hfsplus_find_root_file() con fallback de nodos..."

awk '
  BEGIN { in_find = 0; }

  {
    /* Detectar el inicio de la función original */
    if (!in_find && $0 ~ /static int hfsplus_find_root_file\(const char\* name, ForkMeta\* out_fork\)\{/){
      in_find = 1;

      print "static int hfsplus_find_root_file(const char* name, ForkMeta* out_fork){";
      print "    uint32_t parent = 2; /* root CNID */";
      print "";
      print "    /* Leer nodo 0 del catalog (header del B-tree) */";
      print "    if (fork_read(&hv.cat, 0, secbuf, 4096)) return -1;";
      print "    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;";
      print "";
      print "    /* Header del B-tree HFS+ (big-endian) */";
      print "    typedef struct {";
      print "        uint16_t treeDepth;";
      print "        uint32_t rootNode;";
      print "        uint32_t leafRecords;";
      print "        uint32_t firstLeafNode;";
      print "        uint32_t lastLeafNode;";
      print "        uint16_t nodeSize;";
      print "        uint16_t maxKeyLength;";
      print "        uint32_t totalNodes;";
      print "        uint32_t freeNodes;";
      print "        uint16_t reserved1;";
      print "        uint32_t clumpSize;";
      print "        uint8_t  btreeType;";
      print "        uint8_t  keyCompareType;";
      print "        uint32_t attributes;";
      print "        uint32_t reserved3[16];";
      print "    } __attribute__((packed)) BTHeaderRecLocal;";
      print "";
      print "    BTHeaderRecLocal* hdr = (BTHeaderRecLocal*)(secbuf + sizeof(BTNodeDescriptor));";
      print "    uint16_t nodeSize   = be16(hdr->nodeSize);";
      print "    uint32_t firstLeaf  = be32(hdr->firstLeafNode);";
      print "    uint32_t lastLeaf   = be32(hdr->lastLeafNode);";
      print "    uint16_t depth      = be16(hdr->treeDepth);";
      print "    uint32_t totalNodes = be32(hdr->totalNodes);";
      print "";
      print "    if (!nodeSize) nodeSize = 4096; /* fallback razonable */";
      print "";
      print "    puts(\"[hfs+] find_root: depth=\");";
      print "    putu32(depth);";
      print "    puts(\" nodeSize=\");";
      print "    putu32(nodeSize);";
      print "    puts(\" totalNodes=\");";
      print "    putu32(totalNodes);";
      print "    puts(\" firstLeaf=\");";
      print "    putu32(firstLeaf);";
      print "    puts(\" lastLeaf=\");";
      print "    putu32(lastLeaf);";
      print "    puts(\"\\r\\n\");";
      print "";
      print "    /* Si totalNodes viene en 0, lo derivamos del tamaño del fork del catálogo */";
      print "    if (!totalNodes) {";
      print "        totalNodes = (uint32_t)(hv.cat.size / nodeSize);";
      print "    }";
      print "";
      print "    /* Si el header no da rango de hojas o da algo fuera de rango, usar 1..totalNodes-1 */";
      print "    if ((firstLeaf == 0 && lastLeaf == 0) || firstLeaf >= totalNodes || lastLeaf >= totalNodes) {";
      print "        if (totalNodes > 1) {";
      print "            firstLeaf = 1;";
      print "            lastLeaf  = totalNodes - 1;";
      print "        } else {";
      print "            firstLeaf = 0;";
      print "            lastLeaf  = 0;";
      print "        }";
      print "    }";
      print "";
      print "    /* Recorremos nodos en el rango [firstLeaf, lastLeaf] */";
      print "    for (uint32_t node = firstLeaf; node <= lastLeaf; node++){";
      print "        uint64_t off = (uint64_t)node * nodeSize;";
      print "        if (fork_read(&hv.cat, off, secbuf, nodeSize)) return -1;";
      print "        BTNodeDescriptor* d = (BTNodeDescriptor*)secbuf;";
      print "        uint16_t num = be16(d->numRecords);";
      print "";
      print "        puts(\"[hfs+] root-scan node=\");";
      print "        putu32(node);";
      print "        puts(\" kind=\");";
      print "        putu32((uint32_t)(uint8_t)d->kind);";
      print "        puts(\" num=\");";
      print "        putu32(num);";
      print "        puts(\"\\r\\n\");";
      print "";
      print "        /* Sólo tiene sentido mirar registros en nodos hoja */";
      print "        if ((uint8_t)d->kind != 0xFF || !num) continue;";
      print "";
      print "        uint16_t* idxv = (uint16_t*)(secbuf + nodeSize - 2 * (num + 1));";
      print "";
      print "        for (uint16_t r = 0; r < num; r++){";
      print "            uint16_t rec_off = be16(idxv[r]);";
      print "            uint8_t* rec = secbuf + rec_off;";
      print "";
      print "            HFSPlusCatalogKey* key = (HFSPlusCatalogKey*)rec;";
      print "            uint32_t p_id = be32(key->parentID);";
      print "            uint16_t nlen  = be16(key->nameLen);";
      print "            const uint8_t* uname = rec + 2 + 4 + 2;";
      print "            char tmp[128];";
      print "            u16be_to_ascii(uname, nlen, tmp, 128);";
      print "";
      print "            uint8_t* data  = rec + 2 + be16(key->keyLength);";
      print "            uint16_t rtype = be16(*(uint16_t*)data);";
      print "";
      print "            if (p_id == parent && rtype == 0x0002 && s_eq(tmp, name)){";
      print "                HFSPlusFileRecord* ff = (HFSPlusFileRecord*)data;";
      print "                if (out_fork){";
      print "                    out_fork->size = be64(ff->dataFork.logicalSize);";
      print "                    for (int i = 0; i < 8; i++){";
      print "                        out_fork->ext[i].start = be32(ff->dataFork.extents[i].startBlock);";
      print "                        out_fork->ext[i].count = be32(ff->dataFork.extents[i].blockCount);";
      print "                    }";
      print "                }";
      print "                return 0;";
      print "            }";
      print "        }";
      print "    }";
      print "";
      print "    return -1;";
      print "}";
      next;
    }

    /* Mientras estamos dentro del cuerpo viejo, lo saltamos hasta el cierre */
    if (in_find) {
      if ($0 ~ /^}/) {
        in_find = 0;
      }
      next;
    }

    /* Restante del archivo tal cual */
    print;
  }
' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new

mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c

echo "[patch_hfs_find_root_leaf2] listo. Ahora ejecuta: ./build_run.sh"
