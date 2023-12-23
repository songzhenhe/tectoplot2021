# tectoplot
# bashscripts/download_datasets.sh
# Copyright (c) 2021 Kyle Bradley, all rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# This function will check for and attempt to download data.

function check_and_download_dataset() {

  DOWNLOADNAME=$1
  DOWNLOAD_SOURCEURL=$2
  DOWNLOADGETZIP=$3
  DOWNLOADDIR=$4
  DOWNLOADFILE=$5
  DOWNLOADZIP=$6
  DOWNLOADFILE_BYTES=$7
  DOWNLOADZIP_BYTES=$8

  # Uncomment to understand why a download command is failing
  # echo DOWNLOADNAME=$1
  # echo DOWNLOAD_SOURCEURL=$2
  # echo DOWNLOADGETZIP=$3
  # echo DOWNLOADDIR=$4
  # echo DOWNLOADFILE=$5
  # echo DOWNLOADZIP=$6
  # echo DOWNLOADFILE_BYTES=$7
  # echo DOWNLOADZIP_BYTES=$8

  # First check if the download directory exists. If not, create it.

  info_msg "Checking ${DOWNLOADNAME}..."
  if [[ ! -d "${DOWNLOADDIR}" ]]; then
    info_msg "${DOWNLOADNAME} directory ${DOWNLOADDIR} does not exist. Creating."
    mkdir -p "${DOWNLOADDIR}"
  else
    info_msg "${DOWNLOADNAME} directory ${DOWNLOADDIR} exists."
  fi

  trytounzipflag=0
  testfileflag=0

  # Check if the target download file exists

  if [[ ! -e "${DOWNLOADFILE}" ]]; then

    # If the target file doesn't already exist, check if we need to download an archive file
    if [[ $DOWNLOADGETZIP =~ "yes" ]]; then

      # If we need to download a ZIP file, check if we have the ZIP file already
      if [[ -e ${DOWNLOADZIP} ]]; then

        # If we already have a ZIP file, check whether its size matches the
        if [[ ! $DOWNLOADZIP_BYTES =~ "none" ]]; then

          # If the size of the zip is not labeled as 'none', measure its size
          filebytes=$(wc -c < "${DOWNLOADZIP}")
          if [[ $(echo "$filebytes == ${DOWNLOADZIP_BYTES}" | bc) -eq 1 ]]; then

            # If the ZIP file matches the expecte size, we are OK
             info_msg "${DOWNLOADNAME} archive file exists and is complete"
          else
            # If the ZIP file doesn't match in size, try to continue its download from its present state
             info_msg "Trying to resume ${DOWNLOADZIP} download. If this doesn't work, delete ${DOWNLOADZIP} and retry."
             if ! curl --fail -L -C - "${DOWNLOAD_SOURCEURL}" -o "${DOWNLOADZIP}"; then
               info_msg "Attempted resumption of ${DOWNLOAD_SOURCEURL} download using curl failed."
               echo "${DOWNLOADNAME}_resume" >> tectoplot.failed
             else
               trytounzipflag=1 # curl succeeded, so we will try to extract the ZIP
             fi
          fi
        fi
      fi

      # If we need to download an archive file but don't have it yet,

      if [[ ! -e "${DOWNLOADZIP}" ]]; then

        # Trt to download the archive
        info_msg "${DOWNLOADNAME} file ${DOWNLOADFILE} and ZIP do not exist. Downloading ZIP from source URL into ${DOWNLOADDIR}."
        if ! curl --fail -L "${DOWNLOAD_SOURCEURL}" -o "${DOWNLOADZIP}"; then
          info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
          echo "${DOWNLOADNAME}" >> tectoplot.failed
        else
          trytounzipflag=1
        fi
      fi

      # If the archive exists and we are clear to extract it

      if [[ -e "${DOWNLOADZIP}" && $trytounzipflag -eq 1 ]]; then
        if [[ ${DOWNLOADZIP: -4} == ".zip" ]]; then
           unzip -n "${DOWNLOADZIP}" -d "${DOWNLOADDIR}"
        elif [[ ${DOWNLOADZIP: -4} == ".tbz" ]]; then
           bunzip2 "${DOWNLOADZIP}"
           tar -xf "${DOWNLOADZIP:0:${#DOWNLOADZIP}-4}.tar" -C "${DOWNLOADDIR}"
        elif [[ ${DOWNLOADZIP: -6} == "tar.gz" ]]; then
           mkdir -p "${DOWNLOADDIR}"
           tar -xf "${DOWNLOADZIP}" -C "${DOWNLOADDIR}"
        fi
        testfileflag=1
      fi

      # End processing of archive file

    else  # We don't need to download a ZIP - just download the file directly
      if ! curl --fail -L "${DOWNLOAD_SOURCEURL}" -o "${DOWNLOADFILE}"; then
        info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
        echo "${DOWNLOADNAME}" >> tectoplot.failed
      else
        testfileflag=1
      fi
    fi
  else
    info_msg "${DOWNLOADNAME} file ${DOWNLOADFILE} already exists."
    testfileflag=1
  fi

  # If we are clear to test the target file
  if [[ $testfileflag -eq 1 ]]; then

    # If the file has an expected size
    if [[ ! $DOWNLOADFILE_BYTES =~ "none" ]]; then
      filebytes=$(wc -c < "${DOWNLOADFILE}")
      if [[ $(echo "$filebytes == ${DOWNLOADFILE_BYTES}" | bc) -eq 1 ]]; then
        info_msg "${DOWNLOADNAME} file size is verified."
        if [[ ${DOWNLOADGETZIP} =~ "yes" && ${DELETEZIPFLAG} -eq 1 ]]; then
          echo "Deleting zip archive"
          rm -f "${DOWNLOADZIP}"
        fi
      else
        info_msg "File size mismatch for ${DOWNLOADFILE} ($filebytes should be $DOWNLOADFILE_BYTES). Trying to continue download."
        if ! curl --fail -L -C - "${DOWNLOAD_SOURCEURL}" -o "${DOWNLOADFILE}"; then
          info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
          echo "${DOWNLOADNAME}" >> tectoplot.failed
        else
          filebytes=$(wc -c < "${DOWNLOADFILE}")
          if [[ $(echo "$filebytes == ${DOWNLOADFILE_BYTES}" | bc) -eq 1 ]]; then
            info_msg "Redownload of ${DOWNLOADNAME} file size is verified."
            if [[ ${DOWNLOADGETZIP} =~ "yes" && ${DELETEZIPFLAG} -eq 1 ]]; then
              echo "Deleting zip archive"
              rm -f "${DOWNLOADZIP}"
            fi
          else
            info_msg "Redownload of ${DOWNLOADFILE} ($filebytes) does not match expected size ($DOWNLOADFILE_BYTES)."
          fi
        fi
      fi
    fi
  fi
}
