# Coconut Access Probe

PoC separada para localizar y leer el contenedor de PosterBoard en el iPhone, sin UUID suministrado desde Mac. **No instala wallpapers. No validada aún en hardware.**

Objetivo habilitado: iPhone 16 Pro (`iPhone17,1`), iOS 18.6.2 (`22G100`). No se ejecuta automáticamente ni con un depurador conectado. El motor puede ocasionar un reinicio; abrir la app no lo ejecuta.

## Construcción

Desde este directorio:

```sh
swift test
xcodegen generate
xcodebuild -project CoconutAccessProbe.xcodeproj -scheme CoconutAccessProbe \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/coconut-access-probe CODE_SIGNING_ALLOWED=NO build
```

La compilación sin firma comprueba el enlace arm64e; no produce una IPA instalable con firma de desarrollo. La app de prueba no sustituye Coconut ni cambia sus fondos. Los tests de Swift usan directorios temporales del Mac: comprueban la identificación de contenedores y errores, no el exploit.

Validación del 16-10-2026: compilación Release para iPhone completada y cuatro tests del lector aprobados. La firma automática de Apple falló por ausencia de un perfil/dispositivos registrados para el nuevo identificador; el iPhone sí aparece conectado en CoreDevice. La IPA empaquetada se identifica expresamente como **sin firmar** y requiere firma antes de instalarla. No se instaló ni se ejecutó el motor en el teléfono. La prueba no amplía todavía la compatibilidad de Coconut.

## Fuente y licencia

El motor nativo procede de [Eagle](https://github.com/leonardob8777-bit/Eagle), commit `2b0dc8f1a30a3bde85ec98893645ed2d952b2a96`, basado en Lara y DarkSword. Se conservan los encabezados de autoría de ruter y colaboradores. La aplicación combinada de esta carpeta se rige por AGPL-3.0; el texto está en [Vendor/EagleAccess/LICENSE](Vendor/EagleAccess/LICENSE). El lector propio conserva GPL-3.0 y su texto está en el LICENSE de la raíz del proyecto Coconut.

XPF (Lars Fröder), libgrabkernel2 (Alfie CG) y ChOma tienen sus avisos en `Vendor/EagleAccess/lara/licenses`. Se conservaron los dos binarios de bibliotecas y las cabeceras de la revisión auditada; no se recompilaron esos binarios. `Vendor/EagleAccess/provenance.json` identifica cada archivo, su SHA-256 de origen, el SHA-256 local y las modificaciones. La app principal Coconut no enlaza este laboratorio.

Se quitaron de `darksword.m` las ramas de recuperación/transferencia a launchd y la opción `stashKRW`; no se incluyó `persistence.m`. El núcleo del exploit y `sbx_escape` no fueron ampliados a modelos o versiones nuevos. La interfaz pública del puente solo permite iniciar la comprobación específica; no expone lectura o escritura arbitraria del kernel a la galería.

Para distribuir la IPA de esta PoC debe acompañarse de las fuentes correspondientes y estos avisos. Consulta la auditoría [ACCESO-SIN-MAC](../../docs/ACCESO-SIN-MAC.md) para los límites y la integración pendiente.
