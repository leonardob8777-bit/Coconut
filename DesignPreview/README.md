# Revisión visual de Coconut

Esta aplicación de simulador usa las mismas pantallas SwiftUI que Coconut. No enlaza el código nativo de acceso al sistema, no ejecuta el instalador y no produce una IPA.

```sh
xcodegen generate --spec DesignPreview/project.yml
xcodebuild -project DesignPreview/CoconutDesignPreview.xcodeproj \
  -scheme CoconutDesignPreview -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/coconut-design build
```

La galería y los vídeos funcionan sin red con la colección incluida. Guardar y marcar favoritos sí persiste en el sandbox de esta app de revisión. La pantalla de aplicación es una revisión visual; su botón final está deshabilitado en el simulador.

## Dirección visual

- Lienzo piedra en claro y grafito en oscuro. Los fondos conservan sus colores originales.
- SF para la interfaz; New York en la selección editorial. Los textos, espaciados y pesos establecen jerarquía sin decoraciones brillantes.
- Liquid Glass nativo en la navegación y controles de iOS 26; material del sistema como alternativa en versiones anteriores.
- Explorar reúne una selección destacada, filtros, búsqueda y colección. Tocar un tema abre su detalle.
- El detalle muestra la composición completa, imagen o vídeo, reloj de referencia opcional, favoritos, guardar y usar fondo.
- Mi colección reúne guardados, favoritos e importación. Compartir y eliminar quedan en menús contextuales.
- No se llama al instalador al entrar en una pantalla. Los mensajes distinguen preparación, archivo importado y selección en iOS.

## Recursos

Los `*-artwork.jpg` y `*-motion.mp4` son representaciones locales de las capas CAML existentes, sin barras, reloj ni etiquetas del visor. No alteran los archivos `.tendies`. Se generan con `tools/GalleryRenderer` y `tools/render_gallery_previews.py`.

La revisión visual no certifica la aplicación del fondo en un iPhone.

Los vídeos limpios se muestrean a 30 fotogramas por segundo, con un reloj de animación determinista. La exportación puede tardar más que la duración del clip: no descarta fotogramas cuando el simulador va lento. El reloj visible en el detalle es opcional y está apagado por defecto; no forma parte de las imágenes ni de los vídeos.

Referencias de plataforma: [Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/liquid-glass) y [materiales de las Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/materials). El material se reserva para navegación y controles; la colección mantiene superficies neutras.
