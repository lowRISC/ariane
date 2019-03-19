/*----------------------------------------------------------------------------
 * Copyright (c) 2013-2015, The Regents of the University of California (Regents).
 * All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the Regents nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 
 * IN NO EVENT SHALL REGENTS BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
 * SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
 * OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF REGENTS HAS
 * BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * REGENTS SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE. THE SOFTWARE AND ACCOMPANYING DOCUMENTATION, IF ANY, PROVIDED
 * HEREUNDER IS PROVIDED "AS IS". REGENTS HAS NO OBLIGATION TO PROVIDE
 * MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *----------------------------------------------------------------------------
 * Copyright (c) 2015-2017, University of Cambridge.
 * All Rights Reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University of Cambridge nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 
 * IN NO EVENT SHALL UNIVERSITY OF CAMBRIDGE BE LIABLE TO ANY PARTY FOR DIRECT,
 * INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS,
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF REGENTS
 * HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * UNIVERSITY OF CAMBRIDGE SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE. THE SOFTWARE AND ACCOMPANYING DOCUMENTATION, IF ANY,
 * PROVIDED HEREUNDER IS PROVIDED "AS IS". UNIVERSITY OF CAMBRIDGE HAS NO
 * OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
 * MODIFICATIONS.
 *----------------------------------------------------------------------------*/

#include "elfriscv.h"
#include <string.h>
// #include <stdio.h>
#include "mini-printf.h"
#include "hash-md5.h"

#ifndef IS_ELF64
#define IS_ELF(hdr)					  \
  ((hdr).e_ident[0] == 0x7f && (hdr).e_ident[1] == 'E' && \
   (hdr).e_ident[2] == 'L'  && (hdr).e_ident[3] == 'F')

#define IS_ELF32(hdr) (IS_ELF(hdr) && (hdr).e_ident[4] == 1)
#define IS_ELF64(hdr) (IS_ELF(hdr) && (hdr).e_ident[4] == 2)
#endif

int load_elf(const uint8_t *elf, const uint32_t elf_size) {
  // sanity checks
  if(elf_size <= sizeof(Elf64_Ehdr))
    return 1;                   /* too small */

  const Elf64_Ehdr *eh = (const Elf64_Ehdr *)elf;
  if(!IS_ELF64(*eh))
    return 2;                   /* not a elf64 file */

  const Elf64_Phdr *ph = (const Elf64_Phdr *)(elf + eh->e_phoff);
  if(elf_size < eh->e_phoff + eh->e_phnum*sizeof(*ph))
    return 3;                   /* internal damaged */

  uint32_t i;
  for(i=0; i<eh->e_phnum; i++) {
    if(ph[i].p_type == PT_LOAD && ph[i].p_memsz) { /* need to load this physical section */
      printf("Section[%d]: ", i);
      if(ph[i].p_filesz) {                         /* has data */
	uint8_t *paddr = (uint8_t *)ph[i].p_paddr;
	const uint8_t *elf_offset = elf + ph[i].p_offset;
	size_t len = ph[i].p_filesz;
	size_t extent = ph[i].p_offset + len;
        if(elf_size < extent)
	  {
	    printf("len required = %X, actual = %x\n", extent, elf_size);
	    return 3;             /* internal damaged */
	  }
	printf("memcpy(%x,0x%x,0x%x);\n", paddr, elf_offset, len);
        memcpy(paddr, elf_offset, len);
#ifdef VERBOSE_MD5
        hash_buf(paddr, len);
#endif        
      }
      if(ph[i].p_memsz > ph[i].p_filesz) { /* zero padding */
	uint8_t *bss = (uint8_t *)ph[i].p_paddr + ph[i].p_filesz;
	size_t len = ph[i].p_memsz - ph[i].p_filesz;
	printf("memset(%x,0,0x%x);\n", bss, len);
        memset(bss, 0, len);
#ifdef VERBOSE_MD5
	hash_buf(bss, len);
#endif
      }
    }
  }

  return 0;
}
