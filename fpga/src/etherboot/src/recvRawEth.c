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

#include <sys/types.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <net/ethernet.h>
#include <fcntl.h>
#include <netinet/ip.h>
#include <netinet/in.h>
#include <assert.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netdb.h>
#include <stdint.h>
#include <string.h>
#include "hash-md5.h"

#define SERVER "192.168.0.51"
#define BUFLEN 1536  //Max length of buffer
#define PORT "8888"   //The port on which to send data
#define CHUNK_SIZE 1456

enum {sizeof_maskarray=CHUNK_SIZE};

#define IS_ELF(hdr) \
  ((hdr).e_ident[0] == 0x7f && (hdr).e_ident[1] == 'E' && \
   (hdr).e_ident[2] == 'L'  && (hdr).e_ident[3] == 'F')

#define IS_ELF32(hdr) (IS_ELF(hdr) && (hdr).e_ident[4] == 1)
#define IS_ELF64(hdr) (IS_ELF(hdr) && (hdr).e_ident[4] == 2)

#define PT_LOAD 1

#define SHT_NOBITS 8

typedef struct {
  uint8_t  e_ident[16];
  uint16_t e_type;
  uint16_t e_machine;
  uint32_t e_version;
  uint32_t e_entry;
  uint32_t e_phoff;
  uint32_t e_shoff;
  uint32_t e_flags;
  uint16_t e_ehsize;
  uint16_t e_phentsize;
  uint16_t e_phnum;
  uint16_t e_shentsize;
  uint16_t e_shnum;
  uint16_t e_shstrndx;
} Elf32_Ehdr;

typedef struct {
  uint32_t sh_name;
  uint32_t sh_type;
  uint32_t sh_flags;
  uint32_t sh_addr;
  uint32_t sh_offset;
  uint32_t sh_size;
  uint32_t sh_link;
  uint32_t sh_info;
  uint32_t sh_addralign;
  uint32_t sh_entsize;
} Elf32_Shdr;

typedef struct
{
  uint32_t p_type;
  uint32_t p_offset;
  uint32_t p_vaddr;
  uint32_t p_paddr;
  uint32_t p_filesz;
  uint32_t p_memsz;
  uint32_t p_flags;
  uint32_t p_align;
} Elf32_Phdr;

typedef struct
{
  uint32_t st_name;
  uint32_t st_value;
  uint32_t st_size;
  uint8_t  st_info;
  uint8_t  st_other;
  uint16_t st_shndx;
} Elf32_Sym;

typedef struct {
  uint8_t  e_ident[16];
  uint16_t e_type;
  uint16_t e_machine;
  uint32_t e_version;
  uint64_t e_entry;
  uint64_t e_phoff;
  uint64_t e_shoff;
  uint32_t e_flags;
  uint16_t e_ehsize;
  uint16_t e_phentsize;
  uint16_t e_phnum;
  uint16_t e_shentsize;
  uint16_t e_shnum;
  uint16_t e_shstrndx;
} Elf64_Ehdr;

typedef struct {
  uint32_t sh_name;
  uint32_t sh_type;
  uint64_t sh_flags;
  uint64_t sh_addr;
  uint64_t sh_offset;
  uint64_t sh_size;
  uint32_t sh_link;
  uint32_t sh_info;
  uint64_t sh_addralign;
  uint64_t sh_entsize;
} Elf64_Shdr;

typedef struct {
  uint32_t p_type;
  uint32_t p_flags;
  uint64_t p_offset;
  uint64_t p_vaddr;
  uint64_t p_paddr;
  uint64_t p_filesz;
  uint64_t p_memsz;
  uint64_t p_align;
} Elf64_Phdr;

typedef struct {
  uint32_t st_name;
  uint8_t  st_info;
  uint8_t  st_other;
  uint16_t st_shndx;
  uint64_t st_value;
  uint64_t st_size;
} Elf64_Sym;

#ifndef IS_ELF64
#define IS_ELF(hdr)					  \
  ((hdr).e_ident[0] == 0x7f && (hdr).e_ident[1] == 'E' && \
   (hdr).e_ident[2] == 'L'  && (hdr).e_ident[3] == 'F')

#define IS_ELF32(hdr) (IS_ELF(hdr) && (hdr).e_ident[4] == 1)
#define IS_ELF64(hdr) (IS_ELF(hdr) && (hdr).e_ident[4] == 2)
#endif

void download(uint8_t *paddr, const uint8_t *elf_offset, size_t len);
void clear(uint8_t *bss, size_t len);

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
	    printf("len required = %lX, actual = %x\n", extent, elf_size);
	    return 3;             /* internal damaged */
	  }
	printf("download(%p,0x%p,0x%zx);\n", paddr, elf_offset, len);
        download(paddr, elf_offset, len);
#ifdef VERBOSE_MD5
        hash_buf(paddr, len);
#endif        
      }
      if(ph[i].p_memsz > ph[i].p_filesz) { /* zero padding */
	uint8_t *bss = (uint8_t *)ph[i].p_paddr + ph[i].p_filesz;
	size_t len = ph[i].p_memsz - ph[i].p_filesz;
	printf("clear(%p,0x%zx);\n", bss, len);
        clear(bss, len);
#ifdef VERBOSE_MD5
	hash_buf(bss, len);
#endif
      }
    }
  }

  return 0;
}

void die(char *s)
{
    perror(s);
    exit(1);
}

static uint64_t maskarray[sizeof_maskarray/8];
struct sockaddr_in si_other;
char downloaded[BUFLEN], digest[MD5_DIGEST_LENGTH*2+1];

void send_message(int s, uint16_t idx, char message[BUFLEN])
{
  int len = CHUNK_SIZE+sizeof(uint16_t);
  memcpy(message+CHUNK_SIZE, &idx, sizeof(uint16_t));
#ifdef DEBUG
  printf("send_message idx 0x%x\n", idx);
#endif  
  //send the message
  if (write(s, message, len) != len)
    die("send_message()");
}

int recv_message(int s, int typ)
{
  int update = 0;
  int len = 0;
  uint8_t payload[BUFLEN];
  do {
    len = read(s, payload, BUFLEN);
    if (len > 0)
      {
#if 1
          printf("listener: got packet %u bytes\n", len);
#endif          
          switch (len)
            {
            case sizeof(maskarray):
              memcpy(maskarray, payload, len);
              update = (len==typ) || (len==CHUNK_SIZE);
              break;
            case 34:
            case MD5_DIGEST_LENGTH*2+1:
              memcpy(digest, payload, len);
              update = (len==typ);
              break;
            default:
              memcpy(downloaded, payload, len);
              update = (len==typ);
              if (!update)
                printf("Don't know what to do with message of length %d\n", len);
              break;
            }
      }
  }
  while ((len > 0) && !update);
  return len;
}

static void md5_bin2hex(char *p, const char *cp)
{
  static const char *hex = "0123456789abcdef";
  int count = 16;
  while (count) {
  unsigned char c = *cp++;

  *p++ = hex[c >> 4];
  *p++ = hex[c & 0xf];
  count--;
 }
  *p = 0;
}

static int s;

int download_chunk(const unsigned char *m, size_t len, size_t dest)
  {
    int i, chunks, status, restart = 1;
  uint16_t idx;
  uint8_t buf[BUFLEN];
  int incomplete = 1;
  struct ifreq if_ip;	/* get ip addr */
  unsigned char md[MD5_DIGEST_LENGTH];
  unsigned char hex[MD5_DIGEST_LENGTH*2+1];
  /* Header structures */
  struct ether_header *eh = (struct ether_header *) buf;
  struct ip *iph = (struct ip *) (buf + sizeof(struct ether_header));
  struct udphdr *udph = (struct udphdr *) (buf + sizeof(struct ip) + sizeof(struct ether_header));
  chunks = (len+CHUNK_SIZE-1) / CHUNK_SIZE;
  printf("len = %zd, chunks = %d\n", len, chunks);
  assert(chunks < 65536);
  
  memset(&if_ip, 0, sizeof(struct ifreq));
  
  /* restart */
  while (restart)
    {
      printf("Restarting\n");
      do {
        char message[BUFLEN];
        memset(message, 0, sizeof(message));
        send_message(s, 0xFFFE, message);
        usleep(1000);
        status = recv_message(s, sizeof(maskarray));
      }
      while (status != sizeof(maskarray));
      restart = 0;
      for (i = 0; i < sizeof(maskarray)/sizeof(*maskarray); i++)
        {
          if (maskarray[i]) restart = 1;
        }
    }
  
  while (incomplete)
    {
      enum {wait=2, dly=40000};
      int cnt = 0;
      for (idx = 0; idx < chunks; ++idx)
	{
	  if (!(maskarray[idx/64] & (1ULL << (idx&63))))
	    {
              char message[BUFLEN];
	      memcpy(message, m+idx*CHUNK_SIZE, CHUNK_SIZE);
	      //send the message
	      send_message(s, idx, message);
              if (++cnt % wait == 0) usleep(dly);
	    }
	}
      do {
        char message[BUFLEN];
        memset(message, 0, sizeof(message));
        send_message(s, 0xFFFD, message);
        usleep(1000);
        status = recv_message(s, sizeof(maskarray));
      }
      while (status != sizeof(maskarray));
      incomplete = 0;
      for (idx = 0; idx < chunks; ++idx)
	{
	  if (!(maskarray[idx/64] & (1ULL << (idx&63))))
	    {
	      ++incomplete;
	    }
	}
      printf(" %d%%\n", 100*(chunks-incomplete)/chunks);
      fflush(stdout);
    }
  return 0;
}

void compare(size_t dest, const uint8_t *elf_offset, char *digest, char *buf, size_t len)
{
  int i, j, status, chunk = 1024;
  printf("Received digest = %s (expected=%s)\n", digest, buf);
  if (strcmp(digest,buf))
    {
      for (i = 0; i < len; i += chunk)
	{
	  size_t off = dest+i;
	  //	  printf("receive(0x%zx,0x%x);\n", dest+i, chunk);
          char message[BUFLEN];
          memset(message, 0, sizeof(message));
	  memcpy(message, &off, sizeof(size_t));
	  memcpy(message+sizeof(size_t), &chunk, sizeof(size_t));
	  do {
	    send_message(s, 0xFFF9, message);
	    usleep(10000);
            status = recv_message(s, chunk);
	  }
	  while (status != chunk);
	  for (j = 0; j < chunk/sizeof(uint32_t); j++) if (i+j*sizeof(uint32_t) < len)
	    {
	      uint32_t *ptr = (uint32_t *)downloaded;
	      uint32_t *ref = (uint32_t *)elf_offset;
	      if (ptr[j] != ref[i/sizeof(uint32_t)+j])
		printf("@%d %.8X:%.8X\n", j, ptr[j], ref[i/sizeof(uint32_t)+j]);
	    }
	}
    }
}

void download(uint8_t *paddr, const uint8_t *elf_offset, size_t len)
{
  int i, j, status;
  enum {chunk_max = 1 << 24};
  char hbuf[33];
  for (i = 0; i < len; i += chunk_max)
    {
      char message[BUFLEN];
      size_t dest = (size_t)(paddr+i);
      size_t chunklen = len-i < chunk_max ? len-i : chunk_max;
      strcpy(hbuf, hash_buf(elf_offset+i, chunklen));
      printf("download(%p,0x%p,0x%zx);\n", paddr+i, elf_offset+i, chunklen);
      download_chunk(elf_offset+i, chunklen, dest);
#if 0      
      for (j = 0; j < 16; j++)
	{
	  uint32_t *ptr = (uint32_t *)(elf_offset+i);
	  printf("%.8X ", ptr[j]);
	}
#endif      
      printf("\n");
      memcpy(message, &dest, sizeof(size_t));
      memcpy(message+sizeof(size_t), &chunklen, sizeof(size_t));
      do {
        printf("MD5(0x%zx,0x%zx);\n", dest, chunklen);
	send_message(s, 0xFFFC, message);
	usleep(10000);
        status = recv_message(s, 34);
      }
      while (status != 34);
      compare(dest, elf_offset+i, digest, hbuf, chunklen);
    }
}

void clear(uint8_t *bss, size_t len)
{
  char message[BUFLEN];
  size_t dest = (size_t)bss;
  printf("target_clear(0x%zx,0x%zx);\n", dest, len);
  memcpy(message, &dest, sizeof(size_t));
  memcpy(message+sizeof(size_t), &len, sizeof(size_t));
  send_message(s, 0xFFFA, message);
}

int main(int argc, char *argv[])
{
  char sender[INET6_ADDRSTRLEN];
  int i, ret = 0;
  int sockopt;
  int md5digest = 0;
  int go = 1;
  int oldpercent = -1;
  struct ifreq ifopts;	/* set promiscuous mode */
  struct sockaddr_storage their_addr;
  char ifName[IFNAMSIZ];
  socklen_t peer_addr_size;
  int cfd, len, fd, slen, rslt;
  unsigned char *m;
  char *server = SERVER;
  struct addrinfo hints;
  struct addrinfo *result, *rp;
  
  if (!strcmp(argv[1], "-r"))
    {
      printf("-r (restart) is obsolete, ignored\n");
      ++argv;
      --argc;
    }

  if (!strcmp(argv[1], "-d"))
    {
      md5digest = 1;
      ++argv;
      --argc;
    }
  
  if (!strcmp(argv[1], "-s"))
    {
      server = argv[2];
      argv += 2;
      argc -= 2;
    }
  printf("Server(target) set to %s\n", server);

  if (argc < 2)
    die("args: [options] file (e.g. boot.bin)");

  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = AF_INET;    /* Allow IPv4 or IPv6 */
  hints.ai_socktype = SOCK_DGRAM; /* Datagram socket */
  hints.ai_flags = 0;
  hints.ai_protocol = 0;          /* Any protocol */
  
  s = getaddrinfo(server, PORT, &hints, &result);
  if (s != 0) {
    fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(s));
    exit(EXIT_FAILURE);
  }
  
  /* getaddrinfo() returns a list of address structures.
     Try each address until we successfully connect(2).
     If socket(2) (or connect(2)) fails, we (close the socket
     and) try the next address. */
  
  for (rp = result; rp != NULL; rp = rp->ai_next) {
    s = socket(rp->ai_family, rp->ai_socktype,
                 rp->ai_protocol);
    if (s == -1)
      continue;
    
    if (connect(s, rp->ai_addr, rp->ai_addrlen) != -1)
      break;                  /* Success */
    
    close(s);
  }
  
  if (rp == NULL) {               /* No address succeeded */
    fprintf(stderr, "Could not connect\n");
    exit(EXIT_FAILURE);
  }
  
  freeaddrinfo(result);           /* No longer needed */

  if (ifName[0] == '-' || argc > 3)
    {
      fprintf(stderr, "Unhandled option %s\n", argv[1]);
      exit(1);
    }
    
  fd = open(argv[1], O_RDONLY);
  if (fd < 0)
    {
      perror(argv[1]);
    }
  len = lseek(fd, 0, SEEK_END);
  m = (unsigned char *)mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, 0);
  load_elf(m, len);
  if (go)
    {
      char message[BUFLEN];
      memset(message, 0, sizeof(message));
      send_message(s, 0xFFFF, message);
    }
  close(s);
}

