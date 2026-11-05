# AUR Container Format

**Version:** 1.0  
**Magic:** `AUR1`  
**Byte order:** Little-endian  
**Header size:** 36 bytes  
**Extension:** `.aur` (recommended)

## 1. Overview

The AUR container format is a binary executable container used by Auric programs.

An AUR container stores metadata describing an ARM9 executable payload, including its location within the container, its size, its load address, and its entry point.

The format is based on the AOS1 container header used by AuroraOS. The primary distinction is the magic identifier:

- `AUR1` identifies an Auric executable container.
- `AOS1` identifies an AuroraOS-compatible container.

Auric programs are currently ARM9-only. Consequently, all ARM11 metadata fields must be zero.

## 2. File Layout

An AUR container consists of a fixed-size header followed by its ARM9 payload.

```text
+------------------------------+
|                              |
|        AUR1 Header           |
|          36 bytes            |
|                              |
+------------------------------+
|                              |
|                              |
|        ARM9 Payload          |
|                              |
|                              |
+------------------------------+
```

The header describes where the executable payload is located and where it should be loaded into memory.

## 3. Header Structure

The header is exactly 36 bytes and consists of nine fields.

All integer fields are unsigned 32-bit integers stored in little-endian byte order.

| Offset | Size | Field | Description |
|---|---:|---|---|
| `0x00` | 4 | `magic` | Container identifier (`AUR1` or `AOS1`) |
| `0x04` | 4 | `arm9_offset` | ARM9 payload offset |
| `0x08` | 4 | `arm9_size` | ARM9 payload size |
| `0x0C` | 4 | `arm9_load` | ARM9 payload load address |
| `0x10` | 4 | `arm9_entry` | ARM9 execution entry address |
| `0x14` | 4 | `arm11_offset` | ARM11 payload offset |
| `0x18` | 4 | `arm11_size` | ARM11 payload size |
| `0x1C` | 4 | `arm11_load` | ARM11 payload load address |
| `0x20` | 4 | `arm11_entry` | ARM11 execution entry address |

### 3.1 Magic

The first four bytes identify the container format.

Supported values:

| Magic | Description |
|---|---|
| `AUR1` | Native Auric container |
| `AOS1` | AuroraOS-compatible container |

The magic is stored as four literal ASCII bytes, not as an integer.

### 3.2 ARM9 Metadata

The ARM9 fields describe the primary executable payload.

- `arm9_offset`: File offset where the ARM9 payload begins.
- `arm9_size`: Number of bytes in the ARM9 payload.
- `arm9_load`: Memory address where the payload should be loaded.
- `arm9_entry`: Address where execution should begin.

The default ARM9 load address is:

```c
#define AUR_DEFAULT_ARM9_LOAD 0x22000000
```

The default entry address is equal to the load address unless explicitly specified.

### 3.3 ARM11 Metadata

Auric executables currently do not contain an ARM11 payload.

All ARM11 fields must therefore be zero:

```c
arm11_offset = 0;
arm11_size = 0;
arm11_load = 0;
arm11_entry = 0;
```

A zero `arm11_size` indicates that no ARM11 payload is present.

## 4. Payload Layout

The ARM9 payload begins immediately after the header in standard AUR containers.

```text
arm9_offset = 36
```

The payload size is specified by `arm9_size`.

The payload occupies the following file range:

```text
[arm9_offset, arm9_offset + arm9_size)
```

The end offset is exclusive.

The standard AUR1 layout is therefore:

```text
+------------------------------+ 0x00000000
| Header                       |
| 36 bytes                     |
+------------------------------+ 0x00000024
| ARM9 Payload                 |
| arm9_size bytes              |
+------------------------------+
```

## 5. Binary Representation

The header uses the following packed C representation:

```c
#include <stdint.h>

typedef struct
{
    char magic[4];

    uint32_t arm9_offset;
    uint32_t arm9_size;
    uint32_t arm9_load;
    uint32_t arm9_entry;

    uint32_t arm11_offset;
    uint32_t arm11_size;
    uint32_t arm11_load;
    uint32_t arm11_entry;

} AurHeader;
```

The structure must be packed or otherwise guaranteed to have a size of exactly 36 bytes.

```c
_Static_assert(sizeof(AurHeader) == 36,
               "Invalid AUR header size");
```

This representation assumes a little-endian host when directly reading or writing the structure. Portable implementations should explicitly encode and decode the integer fields.

## 6. Validation Requirements

A conforming AUR container reader should validate the following conditions:

1. The file must contain at least 36 bytes.
2. The magic must be a recognized identifier.
3. Payload offsets must not point inside the header.
4. Payload ranges must not extend beyond the end of the file.
5. ARM9 and ARM11 payload ranges must not overlap when both are present.
6. When `arm11_size` is zero, all other ARM11 metadata fields must also be zero.
7. The ARM9 payload must be nonempty for a valid executable.

For ARM9-only Auric containers, the ARM11 metadata must always be zero.

Load addresses and entry points should also be checked against the target platform's memory map and execution requirements.

## 7. Memory Considerations

The default ARM9 load address is:

```text
0x22000000
```

The AuroraOS loader occupies the following ARM9 address range:

```text
0x08006800 - 0x08100000
```

A payload should not overlap memory occupied by the loader.

The packer may issue a warning when an overlap is detected. This warning does not itself prevent the container from being generated.

The loader is responsible for ensuring that the requested destination memory is valid and available before copying the payload.

## 8. AOS1 Compatibility

AUR1 and AOS1 share the same 36-byte header layout.

Their only structural difference is the magic identifier.

Older AuroraOS firmware loaders may recognize only `AOS1`. For compatibility testing, an Auric program can be packed using the `AOS1` identifier.

This allows the executable to be tested through an older loader without changing the header structure.

However, this compatibility does not guarantee that every Auric program is compatible with older firmware environments.

## 9. Packing and Inspection

Auric provides a utility for creating and inspecting containers.

### 9.1 Create an AUR1 Container

```bash
python aur.py pack program.bin -o program.aur
```

### 9.2 Specify Load and Entry Addresses

```bash
python aur.py pack program.bin \
    --arm9-load 0x22000000 \
    --arm9-entry 0x22000000 \
    -o program.aur
```

### 9.3 Create an AOS1 Container

```bash
python aur.py pack program.bin \
    --magic AOS1 \
    -o program.aur
```

### 9.4 Inspect a Container

```bash
python aur.py info program.aur
```

Example output:

```text
program.aur: AUR1 container, 104860 bytes
  ARM9 : offset 0x24  size 104824  load 0x22000000  entry 0x22000000
  ARM11: (none)
```

## 10. Example Header

An example AUR1 header with the default load and entry addresses:

| Field | Value |
|---|---|
| `magic` | `AUR1` |
| `arm9_offset` | `0x00000024` |
| `arm9_size` | Payload size |
| `arm9_load` | `0x22000000` |
| `arm9_entry` | `0x22000000` |
| `arm11_offset` | `0x00000000` |
| `arm11_size` | `0x00000000` |
| `arm11_load` | `0x00000000` |
| `arm11_entry` | `0x00000000` |

## 11. Summary

The AUR format provides a simple executable container for Auric programs.

Its characteristics are:

- Fixed 36-byte header.
- Little-endian integer fields.
- ARM9 executable payload.
- Explicit payload offset and size.
- Explicit load and entry addresses.
- Reserved ARM11 metadata fields.
- Compatibility with the AOS1 header layout.

The format is intentionally simple, allowing bootloaders, packing utilities, and inspection tools to process containers without requiring a complex executable parser.
