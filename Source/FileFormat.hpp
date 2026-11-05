#include <stdint.h>

typedef struct {
  char Magic[4];

  uint32_t Arm9Offset;
  uint32_t Arm9Size;
  uint32_t Arm9Load;
  uint32_t Arm9Entry;

  uint32_t Arm11Offset;
  uint32_t Arm11Size;
  uint32_t Arm11Load;
  uint32_t Arm11Entry;
} AurHeader;
