#!/bin/sh
perl bin/faiupdate -r;
perl bin/faiupdate;
perl bin/faistatus ;

perl bin/faindex -m 100000 2>/dev/null & disown;
perl bin/faindex -m 100000 2>/dev/null & disown;
perl bin/faindex -m 100000 2>/dev/null & disown;
perl bin/faindex -m 100000 2>/dev/null & disown;
perl bin/faindex -m 100000 2>/dev/null & disown;
perl bin/faindex -D -m 100000;
perl bin/faistatus;
