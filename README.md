# Vet JUMP

Juego educativo vertical para iPhone, construido en Swift, SpriteKit, Core Motion y GameKit. Incluye localmente las 800 preguntas ECVIM en `VetJUMP/Data/ecvim.json`, por lo que se puede jugar sin conexión.

## Incluido

- Cinco niveles de 100 plataformas, escenarios progresivos y modo infinito.
- Cuatro personajes desbloqueados desde el inicio.
- Salto con pulsación, planeo táctil e inclinación del iPhone.
- Manzana, plátano, uvas, limón y brócoli con sus reglas clínicas.
- Exámenes de rescate (7/10), brócoli (8/10) y final (15/20), con explicaciones.
- Progreso, preguntas usadas y estadísticas clínicas guardadas en el dispositivo.
- Integración preparada para Game Center: crea los leaderboards `vet_jump_total_score` y `vet_jump_infinite_score` en App Store Connect antes de publicar.

## Abrir y configurar

1. Abre `VetJUMP.xcodeproj` en Xcode 16 o posterior.
2. El target **Vet JUMP** usa el identificador `com.airsoto.vetjump` y el equipo de desarrollo `V685Z9VC3Z`. El perfil de App Store que se configure en Codemagic debe corresponder exactamente a ambos valores.
3. Selecciona tu equipo de firma. La app requiere iOS 16 o posterior.
4. Para cada lanzamiento, actualiza `MARKETING_VERSION`; Codemagic incrementa `CURRENT_PROJECT_VERSION` automáticamente con `BUILD_NUMBER`.

## Codemagic

El archivo `codemagic.yaml` genera un `.ipa` firmado. En Codemagic deben existir el perfil `vetjump_appstore_profile` y el certificado `vetjump_distribution`; ambos han de pertenecer al equipo `V685Z9VC3Z`, y el perfil ha de ser de tipo App Store para `com.airsoto.vetjump`. Apple y App Store Connect no se gestionan desde este repositorio.

## Controles

- Mantén pulsada la pantalla desde una plataforma para cargar el salto y suelta para saltar.
- Vuelve a tocar en el aire para planear; inclina el iPhone hacia atrás para ayudar al planeo y a los lados para corregir la trayectoria.
