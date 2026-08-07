#ifndef EDGE_MEMORY_MAP_HPP
#define EDGE_MEMORY_MAP_HPP

#include <stdint.h>

#ifdef __cplusplus
extern "C" unsigned char __edge_dtcm_base[];
extern "C" unsigned char __edge_dtcm_size[];
extern "C" unsigned char __edge_dtcm_mask[];
#else
extern unsigned char __edge_dtcm_base[];
extern unsigned char __edge_dtcm_size[];
extern unsigned char __edge_dtcm_mask[];
#endif

#define EDGE_DTCM_BASE ((uintptr_t)__edge_dtcm_base)
#define EDGE_DTCM_SIZE ((uintptr_t)__edge_dtcm_size)
#define EDGE_DTCM_MASK ((uintptr_t)__edge_dtcm_mask)

#endif
