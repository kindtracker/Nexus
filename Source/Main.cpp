#include <stdio.h>
#include <string>
#include <unicorn/unicorn.h>

int main(int Argc, char *Argv[]) {
  std::string FileName;

  for (int Idx = 1; Idx < Argc; Idx++) {
    FileName = Argv[Idx];
  }

  if (FileName.empty()) {
    printf("Nexus: No input file\n");
    return 1;
  }

  const char *FileNameC = FileName.c_str();
  FILE *FilePtr = fopen(FileNameC, "rb");
  if (!FilePtr) {
    printf("Nexus: Failed to open %s\n", FileNameC);
    return 1;
  }

  fseek(FilePtr, 0, SEEK_END);
  size_t Size = ftell(FilePtr);
  fseek(FilePtr, 0, SEEK_SET);

  std::string FileContent;
  FileContent.resize(Size);
  fread(FileContent.data(), 1, Size, FilePtr);
  fclose(FilePtr);

  printf("Nexus: Loaded %zu bytes\n", Size);

  return 0;
}
