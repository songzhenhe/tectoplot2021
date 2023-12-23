
# bashscripts/time.sh
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

## Time management functions

# Call without arguments will return current UTC time in the format YYYY-MM-DDTHH:MM:SS
# Call with arguments will add the specified number of
# days hours minutes seconds
# from the current time.
# Example: date_code_utc -7 0 0 0
# Returns: current date minus seven days

function date_shift_utc() {
  TZ=UTC0     # use UTC
  export TZ

  gawk 'BEGIN  {
      exitval = 0

      daycount=0
      hourcount=0
      minutecount=0
      secondcount=0

      if (ARGC > 1) {
          daycount = ARGV[1]
      }
      if (ARGC > 2) {
          hourcount = ARGV[2]
      }
      if (ARGC > 3) {
          minutecount = ARGV[3]
      }
      if (ARGC > 4) {
          secondcount = ARGV[2]
      }
      timestr = strftime("%FT%T")
      date = substr(timestr,1,10);
      split(date,dstring,"-");
      time = substr(timestr,12,8);
      split(time,tstring,":");
      the_time = sprintf("%i %i %i %i %i %i",dstring[1],dstring[2],dstring[3],tstring[1],tstring[2],int(tstring[3]+0.5));
      secs = mktime(the_time);
      newtime = strftime("%FT%T", secs+daycount*24*60*60+hourcount*60*60+minutecount*60+secondcount);
      print newtime
      exit exitval
  }' "$@"
}

### Epoch

function iso8601_to_epoch() {
  TZ=UTC
   gawk '{
     # printf("%s ", $0)
     for(i=1; i<=NF; i++) {
       done=0
       timecode=substr($(i), 1, 19)
       split(timecode, a, "-")
       year=a[1]
       if (year < 1900) {
         print -2209013725
         done=1
       }
       month=a[2]
       split(a[3],b,"T")
       day=b[1]
       split(b[2],c,":")

       hour=c[1]
       minute=c[2]
       second=c[3]

       if (year == 1982 && month == 01 && day == 01) {
         printf("%s ", 378691200 + second + 60*minute * 60*60*hour)
         done=1
       }
       if (year == 1941 && month == 09 && day == 01) {
         printf("%s ", -895153699 + second + 60*minute * 60*60*hour)
         done=1

       }
       if (year == 1941 && month == 09 && day == 01) {
         printf("%s ", -879638400 + second + 60*minute * 60*60*hour)
         done=1
       }

       if (done==0) {
         the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
         # print the_time > "/dev/stderr"
         epoch=mktime(the_time);
         printf("%s ", epoch)
       }
     }
     printf("\n")
  }'
}
