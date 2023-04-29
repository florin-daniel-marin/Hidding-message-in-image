@echo off

pushd scripts

call C:\Users\Daniel\Programe\Xilinx\14.7\ISE_DS\settings64.bat
call clean.bat noref
call build.bat nodup
call run.bat nobuild gui

popd

pause
