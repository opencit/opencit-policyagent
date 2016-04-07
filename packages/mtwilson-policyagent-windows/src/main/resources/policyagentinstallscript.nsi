; Script generated by the HM NIS Edit Script Wizard.

; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "Policy Agent"
!define PRODUCT_VERSION "1.0"
!define PRODUCT_PUBLISHER "Intel, Inc."
!define PRODUCT_WEB_SITE "http://www.intel.com"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; MUI 1.67 compatible ------
!include "MUI.nsh"
!include nsDialogs.nsh
!include "x64.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; License page
#!insertmacro MUI_PAGE_LICENSE "license.txt"
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES

Page Custom bitlockerstart bitlockerend

; Finish page
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.txt"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; MUI end ------

Function bitlockerstart
Var /Global DriveLetter
nsDialogs::Create /NOUNLOAD 1018
Pop $0
${NSD_CreateLabel} 0 0 100% 20% "Drive to be used for creating bitlocker encrypted volume."
${NSD_CreateLabel} 0 10% 50% 10% "Drive Letter (eg 'D:')"
${NSD_CreateText}  0 20% 20% 10% "C:"
Pop $DriveLetter
nsDialogs::Show
FunctionEnd

Function bitlockerend
# TODO add validation of input
${NSD_GetText} $DriveLetter $0
#MessageBox mb_ok $0

${If} ${RunningX64}
    ${DisableX64FSRedirection}

    nsExec::ExecToStack 'powershell -inputformat none -ExecutionPolicy RemoteSigned -File "$INSTDIR\scripts\bitlocker_drive_setup.ps1" $0  '
    Pop $0 # return value/error/timeout
    Pop $1 # printed text, up to ${NSIS_MAX_STRLEN}

    ${EnableX64FSRedirection}
${EndIf}

MessageBox mb_ok "Bitlocker drive setup complete. Please check log file '$INSTDIR\logs\bitlockersetup.log' for more details"
FunctionEnd

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "Installer.exe"
InstallDir "$PROGRAMFILES\Intel\Policy Agent"
ShowInstDetails show
ShowUnInstDetails show

Section "policyagent" SEC01
  # Set output path to the installation directory (also sets the working directory for shortcuts)
  SetOutPath "$INSTDIR"

  # Copy files to installation directory
 
  # bin directory
  SetOutPath "$INSTDIR\bin\commons"
  SetOverwrite try
  File "bin/commons/parse.py"
  File "bin/commons/process_trust_policy.py"
  File "bin/commons/utils.py"
  File "bin/commons/__init__.py"

  SetOutPath "$INSTDIR\bin\encryption"
  File "bin/encryption/crypt.py"
  File "bin/encryption/win_crypt.py"
  File "bin/encryption/__init__.py"

  SetOutPath "$INSTDIR\bin\invocation"
  File "bin/invocation/measure_vm.py"
  File "bin/invocation/stream.py"
  File "bin/invocation/vrtm_invoke.py"
  File "bin/invocation/__init__.py"

  SetOutPath "$INSTDIR\bin"
  File "bin/policyagent-init"
  File "bin/policyagent.py"
  File "bin/__init__.py"

  SetOutPath "$INSTDIR\bin\trustpolicy"
  File "bin/trustpolicy/trust_policy_retrieval.py"
  File "bin/trustpolicy/trust_store_glance_image_tar.py"
  File "bin/trustpolicy/trust_store_swift.py"
  File "bin/trustpolicy/__init__.py"
  
  # configuration directory
  SetOutPath "$INSTDIR\configuration"
  File "configuration/logging_properties.cfg"
  File "configuration/policyagent_nt.properties"
  
  # scripts directory
  SetOutPath "$INSTDIR\scripts"
  File "scripts/bitlocker_drive_setup.ps1"
  
  # env directory
  SetOutPath "$INSTDIR\env"
  
  # logs directory
  SetOutPath "$INSTDIR\logs"

  # repository directory
  SetOutPath "$INSTDIR\repository"

  SetOverwrite ifnewer

  # Create System Environment Variable - POLICYAGENT_HOME
  !define env_hklm 'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
  !define env_hkcu 'HKCU "Environment"'
  WriteRegExpandStr ${env_hklm} POLICYAGENT_HOME $INSTDIR
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

SectionEnd

; These are the programs that are needed by Policyagent.
;Section -Prerequisites
;  SetOutPath "$INSTDIR\prerequisites"
;  MessageBox MB_YESNO "Installing Pre-requisites" /SD IDYES IDNO endPython-lxml
;    File "prerequisites\lxml-3.4.0.win-amd64-py2.7.exe"
;    ExecWait "$INSTDIR\prerequisites\lxml-3.4.0.win-amd64-py2.7.exe"
;    Goto endPython-lxml
;  endPython-lxml:
; SectionEnd
 
Section -AdditionalIcons
  CreateDirectory "$SMPROGRAMS\PolicyAgent"
  CreateShortCut "$SMPROGRAMS\PolicyAgent\Uninstall.lnk" "$INSTDIR\uninst.exe"
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd


Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was successfully removed from your computer."
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove $(^Name) and all of its components?" IDYES +2
  Abort
FunctionEnd

Section Uninstall
  Delete "$INSTDIR\uninst.exe"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\configuration\policyagent_nt.properties"
  Delete "$INSTDIR\configuration\logging_properties.cfg"
  Delete "$INSTDIR\bin\__init__.py"
  Delete "$INSTDIR\bin\__init__.pyc"
  Delete "$INSTDIR\bin\trustpolicy\__init__.pyc"
  Delete "$INSTDIR\bin\trustpolicy\__init__.py"
  Delete "$INSTDIR\bin\trustpolicy\trust_store_swift.py"
  Delete "$INSTDIR\bin\trustpolicy\trust_store_swift.pyc"
  Delete "$INSTDIR\bin\trustpolicy\trust_store_glance_image_tar.pyc"
  Delete "$INSTDIR\bin\trustpolicy\trust_store_glance_image_tar.py"
  Delete "$INSTDIR\bin\trustpolicy\trust_policy_retrieval.pyc"
  Delete "$INSTDIR\bin\trustpolicy\trust_policy_retrieval.py"
  Delete "$INSTDIR\bin\policyagent.py"
  Delete "$INSTDIR\bin\policyagent.pyc"
  Delete "$INSTDIR\bin\policyagent-init"
  Delete "$INSTDIR\bin\invocation\vrtm_invoke.py"
  Delete "$INSTDIR\bin\invocation\vrtm_invoke.pyc"
  Delete "$INSTDIR\bin\invocation\stream.py"
  Delete "$INSTDIR\bin\invocation\stream.pyc"
  Delete "$INSTDIR\bin\invocation\measure_vm.py"
  Delete "$INSTDIR\bin\invocation\measure_vm.pyc"
  Delete "$INSTDIR\bin\invocation\__init__.py"
  Delete "$INSTDIR\bin\invocation\__init__.pyc"
  Delete "$INSTDIR\bin\encryption\__init__.py"
  Delete "$INSTDIR\bin\encryption\__init__.pyc"
  Delete "$INSTDIR\bin\encryption\crypt.pyc"
  Delete "$INSTDIR\bin\encryption\crypt.py"
  Delete "$INSTDIR\bin\encryption\win_crypt.pyc"
  Delete "$INSTDIR\bin\encryption\win_crypt.py"
  Delete "$INSTDIR\bin\commons\__init__.pyc"
  Delete "$INSTDIR\bin\commons\__init__.py"
  Delete "$INSTDIR\bin\commons\utils.pyc"
  Delete "$INSTDIR\bin\commons\utils.py"
  Delete "$INSTDIR\bin\commons\process_trust_policy.pyc"
  Delete "$INSTDIR\bin\commons\process_trust_policy.py"
  Delete "$INSTDIR\bin\commons\parse.pyc"
  Delete "$INSTDIR\bin\commons\parse.py"
  Delete "$INSTDIR\scripts\bitlocker_drive_setup.ps1"
  Delete "$INSTDIR\logs\bitlockersetup.log"

  Delete "$SMPROGRAMS\PolicyAgent\Uninstall.lnk"

  RMDir "$SMPROGRAMS\PolicyAgent"
  RMDir "$INSTDIR\env"
  RMDir "$INSTDIR\configuration"
  RMDir "$INSTDIR\bin\trustpolicy"
  RMDir "$INSTDIR\bin\invocation"
  RMDir "$INSTDIR\bin\encryption"
  RMDir "$INSTDIR\bin\commons"
  RMDir "$INSTDIR\bin"
  RMDir "$INSTDIR\logs"
  RMDir "$INSTDIR\repository"
  RMDir "$INSTDIR\scripts"
  RMDir "$INSTDIR"

  # Remove system environment variable POLICYAGENT_HOME
  DeleteRegValue ${env_hklm} POLICYAGENT_HOME
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  SetAutoClose true
SectionEnd
