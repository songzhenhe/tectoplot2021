#!/bin/bash
# Usage: compile_texture.sh texture_source_dir

TEXTURE_DIR="${1}"
CCOMPILER="${2}"

CFLAGS="-O2 -funroll-loops -lm"

cd "${TEXTURE_DIR}"

rm -f texture texture_image shadow svf

${CCOMPILER} -DNOMAIN -c *.c
${CCOMPILER} ${CFLAGS} *.o texture.c -o texture
${CCOMPILER} ${CFLAGS} *.o shadow.c -o shadow
${CCOMPILER} ${CFLAGS} *.o svf.c -o svf
${CCOMPILER} ${CFLAGS} *.o texture_image.c -o texture_image

# Cleanup
rm -f *.o
