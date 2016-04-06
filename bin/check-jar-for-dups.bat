REM Run from ...java-identity-provider\idp-distribution\target\shibboleth-identity-provider-3.3.0-SNAPSHOT\webapp\WEB-INF\lib

set path=%PATH%;C:\Program Files\Java\jdk1.8.0_11\bin
echo > f.log
for %%i in (*.jar) do (
    echo %%i
    jar tvf %%i > %%i.log
    jar tf %%i >> f.log
)

sort f.log > g.log

REM Now from an appropriate prompt (I use guthub) type
REM
REM uniq -d .\g.log | grep -v .*\/$
REM