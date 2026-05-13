@echo off

echo.

REM Requires brcc32.exe to be on %PATH%
brcc32.exe .\DragAndDrop.rc -fo .\DragAndDrop.res
echo.

pause

exit /b