---
title: 'VMware 가상머신이 안 켜질 때: Internal error 해결법'
description: 'VMware의 "Error while powering on: Internal error"를 해결하는 점검 순서를 정리합니다. 잔여 락 파일(.lck), 프로세스 재시작, 권한, 백신, Hyper-V 충돌.'
pubDate: 'Jul 23 2026'
heroImage: '../../assets/blog-placeholder-4.jpg'
tags: ['VMware', '가상머신', '트러블슈팅']
draft: true
---

잘 쓰던 가상머신을 켜려는데 부팅은 되지 않고 아래 메시지만 뜨고 멈춘 적이 있습니다.

```
Error while powering on: Internal error
```

메시지가 한 줄뿐이라 무엇이 문제인지 힌트를 주지 않습니다. 어제까지 멀쩡하던 VM이 갑자기 안 켜집니다. 이 오류는 대부분 VM 파일 자체의 문제가 아니라 프로세스, 락(lock), 권한 같은 주변 환경 문제입니다. 그래서 VM을 다시 만들지 않고 아래 순서대로 점검하면 대개 살아납니다.

## 왜 이 오류가 나나

"Internal error"는 VMware가 가상머신 프로세스(`vmware-vmx`)를 정상적으로 띄우지 못했을 때 두루뭉술하게 내는 메시지입니다. 대표적인 원인은 다섯 가지입니다.

- **잔여 락 파일(.lck)**: VM이 비정상 종료(강제 종료, 블루스크린, 정전 등)되면, VM 폴더에 걸려 있던 잠금 파일이 지워지지 않고 남습니다. 다음 부팅 때 VMware가 이미 누가 쓰는 중이라고 오판합니다.
- **VMware 관련 프로세스나 서비스가 꼬임**: 백그라운드의 `vmware-vmx`, `vmware-authd` 프로세스가 좀비로 남아 있으면 새 VM을 못 띄웁니다.
- **권한 부족**: 관리자 권한 없이 실행하거나, VM 파일이 저장된 폴더의 접근 권한이 부족한 경우입니다.
- **백신이나 보안 프로그램의 파일 잠금**: 실시간 감시가 VM 디스크 파일을 잡고 있는 경우입니다.
- **(Windows) Hyper-V나 코어 격리와의 충돌**: Hyper-V가 켜져 있으면 VMware Workstation과 가상화 리소스를 두고 충돌할 수 있습니다.

## 해결 순서

### 잔여 락 파일(.lck)부터 정리

가장 효과가 좋았던 방법입니다. 먼저 VMware를 완전히 종료합니다. 그리고 문제의 가상머신이 저장된 폴더를 엽니다. 그 안에서 이름이 `.lck`로 끝나는 파일이나 폴더를 찾습니다. 보통 아래와 같은 형태입니다.

```
내VM.vmx.lck
내VM.vmdk.lck
내VM.vmem.lck
```

VMware가 완전히 꺼진 상태라면 이 `.lck` 항목은 남아 있으면 안 되는 잔여물입니다. 삭제하지 말고 우선 다른 폴더로 옮겨 둡니다. 만약을 위한 백업입니다. 그런 다음 VM을 다시 켭니다. 대부분 이 단계에서 해결됩니다.

> 팁: 지우기 겁난다면 `.lck` 항목을 폴더 하나 만들어 그리로 옮겨 두고, 문제가 없으면 그 백업 폴더째로 지우면 됩니다.

### VMware 프로세스와 서비스 재시작

락 파일을 정리해도 안 켜지면, VMware 관련 프로세스가 꼬여 있을 수 있습니다.

- **Windows**: 작업 관리자에서 `vmware.exe`, `vmware-vmx.exe`, `vmware-authd.exe`를 모두 종료합니다. 그리고 서비스(`services.msc`)에서 VMware Authorization Service를 재시작합니다. 이 서비스가 멈춰 있으면 VM이 안 켜지는 경우가 많습니다.
- **Linux**: 관련 프로세스를 확인하고 정리한 뒤 서비스를 재시작합니다.

```bash
# Linux 기준 예시
ps -ef | grep vmware
sudo systemctl restart vmware      # 배포판이나 설치 방식에 따라 서비스명이 다를 수 있음
```

그런 다음 VMware를 다시 실행하고 VM을 켭니다.

### 관리자 권한으로 실행

VMware Workstation이나 Player를 관리자 권한으로 실행(우클릭 후 관리자 권한으로 실행)해 봅니다. VM 파일이 권한이 까다로운 경로(예: 시스템 보호 폴더)에 있으면 권한 문제로 부팅이 막힙니다. 가능하면 VM은 접근 권한이 넉넉한 일반 사용자 폴더에 두는 것이 좋습니다.

### 백신 실시간 감시 예외 처리

보안 프로그램이 `.vmdk`, `.vmem` 같은 파일을 잡고 있을 수 있습니다. 실시간 감시를 잠시 끄거나, VM 저장 폴더를 검사 예외로 등록한 뒤 다시 시도합니다.

### (Windows) Hyper-V 충돌 확인

Windows에서 Hyper-V, 코어 격리의 메모리 무결성, WSL2 등이 켜져 있으면 VMware와 충돌할 수 있습니다. VMware가 최신 버전이면 공존이 가능하지만, 구버전이라면 Hyper-V 관련 기능을 끄거나 VMware를 업데이트해야 합니다.

## 정리

`Error while powering on: Internal error`는 메시지는 짧지만, 실제로는 VM 데이터가 깨진 게 아니라 켜기 위한 조건이 안 갖춰진 상태인 경우가 대부분입니다. 점검 순서는 다섯 단계입니다.

1. VMware 완전 종료 후 VM 폴더의 `.lck` 잔여 파일 정리 (제일 흔한 원인)
2. `vmware-vmx` 등 프로세스 종료와 VMware Authorization Service 재시작
3. 관리자 권한으로 실행
4. 백신 실시간 감시 예외 처리
5. (Windows) Hyper-V 등 가상화 충돌 점검

제 경우는 1번의 락 파일 정리만으로 해결됐습니다. 비정상 종료 뒤 이 오류를 만났다면 `.lck`부터 확인하는 것을 권합니다.

---

*환경(VMware Workstation, Player, Fusion과 OS 버전)에 따라 서비스명과 경로가 다를 수 있습니다. 파일을 옮기거나 지우기 전에는 VM 폴더 전체를 백업해 두세요.*
