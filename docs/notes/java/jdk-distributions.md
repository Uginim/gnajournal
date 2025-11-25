# JDK 배포판 비교

## 주요 JDK 배포판

| 배포판 | 제공 | 특징 |
|-------|-----|------|
| **OpenJDK** | Oracle/커뮤니티 | 레퍼런스 구현체, 기본 |
| **Amazon Corretto** | AWS | 무료 LTS, AWS 환경 최적화 |
| **Azul Zulu** | Azul Systems | 다양한 플랫폼 지원 |
| **Eclipse Temurin** | Adoptium | 구 AdoptOpenJDK |
| **Oracle JDK** | Oracle | 상용 라이선스 (17+는 무료) |
| **GraalVM** | Oracle | 네이티브 이미지, 다중 언어 |

## LTS (Long Term Support) 버전

LTS 버전은 장기 지원을 받는 안정적인 버전이다.

| 버전 | LTS 여부 | 지원 기간 |
|-----|---------|----------|
| Java 8 | LTS | ~2030 |
| Java 11 | LTS | ~2026 |
| Java 17 | LTS | ~2029 |
| Java 21 | LTS | ~2031 |
| Java 23 | 비 LTS | 6개월 |
| Java 25 | LTS (예정) | - |

## Amazon Corretto

### 특징
- **무료**: 상용 환경에서도 무료
- **LTS 지원**: LTS 버전만 제공 (8, 11, 17, 21, 25)
- **AWS 최적화**: AWS 환경에서 테스트됨
- **크로스 플랫폼**: Linux, macOS, Windows 지원

### 설치 (macOS)

```bash
# Homebrew로 설치
brew install corretto@21

# jenv에 추가
jenv add /Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home

# 글로벌 설정
jenv global corretto64-21.0.9
```

### IntelliJ에서 추가

Homebrew로 설치한 Corretto가 IntelliJ에서 안 보일 경우:

1. **File > Project Structure > SDKs**
2. **+ 버튼 > Add JDK**
3. 경로 입력:
   ```
   /Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home
   ```

## 어떤 배포판을 선택할까?

| 상황 | 추천 |
|-----|-----|
| AWS 배포 예정 | Amazon Corretto |
| 일반적인 개발 | Temurin 또는 Corretto |
| 네이티브 이미지 필요 | GraalVM |
| 엔터프라이즈 지원 필요 | Oracle JDK 또는 Azul |
