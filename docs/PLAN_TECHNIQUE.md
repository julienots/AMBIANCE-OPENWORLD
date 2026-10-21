# SYMBIOTE: ABYSS — Plan technique (Phase 1)

Studio : **SuperEssence** — document rédigé après audit réel de l'environnement.

## 1. Audit de l'environnement (résultats mesurés)

| Élément | Constat | Conséquence |
|---|---|---|
| Dépôt | Vide (aucun commit) | Projet créé de zéro |
| CPU / RAM / disque | 4 cœurs, 15 Go, ~31 Go libres | Suffisant pour Godot + Blender headless |
| JDK | OpenJDK 21 | Signature APK possible (jarsigner + apksig) |
| GitHub releases | Accessible | Godot 4.5.1 + templates d'export téléchargés |
| `dl.google.com` / `maven.google.com` | **Bloqués (403)** | Pas de SDK Android officiel, pas de build Gradle Android |
| Maven Central | Accessible | `apksig 2.3.0` (bibliothèque de signature APK de Google) |
| PyPI | Accessible | `bpy` 5.0.1 (Blender en module Python) pour générer les modèles 3D |
| Rendu | Xvfb + Mesa llvmpipe (OpenGL 4.5) | Le jeu peut être lancé et capturé en images pour vérification |
| Unity | Non installable (licence, taille, éditeur graphique) | Écarté |

## 2. Choix du moteur : Godot 4.5.1

* Open source, sans licence, exportable **sans Gradle** grâce au template APK pré-compilé.
* Scriptable entièrement en texte (GDScript, shaders, scènes) → reproductible et versionnable.
* Rendu **Compatibility (OpenGL ES 3.0)** : compatible avec le plus large parc Android, et
  testable dans le conteneur (llvmpipe). Le rendu Mobile/Vulkan n'apporterait pas de brume
  volumétrique (réservée à Forward+), donc la fumée sera réalisée par shaders dédiés.

### Chaîne de compilation APK (sans SDK Google)
1. Godot exporte l'APK à partir du template officiel `android_release.apk`/`android_debug.apk`.
2. `tools/apksigner/ApkSignerShim.java` remplace l'outil `apksigner` du SDK :
   * signature **v1** via l'API officielle `jdk.security.jarsigner` du JDK,
   * **zipalign** intégré (entrées non compressées alignées sur 4 octets, `.so` sur 4096),
   * signature **v2** via `apksig` (bloc inséré avant le répertoire central).
3. Vérification : `apksigner verify` (apksig) + `jarsigner -verify`.

Limite : l'absence de SDK empêche les plugins Android personnalisés (Gradle build). Le template
standard suffit pour un jeu hors ligne.

## 3. Architecture

```
game/                     Projet Godot
  project.godot
  assets/branding          Logo SuperEssence (écran de démarrage)
  assets/models            .glb générés par tools/assetgen (Blender)
  assets/audio             .wav générés par tools/audiogen (synthèse)
  shaders/                 toon, contour, symbiote, dissolution, fumée, brouillard, énergie…
  src/autoload             Game (état), Save, Settings, Audio, Events, DB (données)
  src/player               Contrôleur, caméra, héros, pouvoirs
  src/combat               Dégâts, statuts, projectiles, zones
  src/enemies              IA (perception vue/bruit/lumière), familles, Dévoreur, boss
  src/world                Régions, interactions (portes, cachettes, lumières, butin)
  src/base                 Terrain creusable par chunks, bâtiments, raids
  src/ui                   HUD tactile, menus, collection, codex, paramètres
tools/
  assetgen/                Scripts Blender (personnages, monstres, décors)
  audiogen/                Synthèse des effets et musiques
  apksigner/               Signature APK
  build_apk.sh             Build APK reproductible
  run_tests.sh             Tests automatisés headless
```

### Modèles 3D
Générés par scripts Blender : squelette → maillage organique (modificateur *Skin* + subdivision),
armature, poids calculés, animations clés (idle, course, attaques, pouvoirs, esquive, réaction,
mort, apparition, pose de présentation), export `.glb`. Matériaux remplacés en jeu par des
shaders toon maison (rampe, liseré, émission).

### Systèmes clés
* **Perception des monstres** : cône de vision + raycast (pas de vision à travers les murs),
  événements de bruit (course, attaques, portes, leurres), luminosité (lampe du joueur, zones éclairées).
* **Dévoreur** : machine à états PATROUILLE → ENQUÊTE → TRAQUE (accélération progressive) →
  RECHERCHE → RETOUR ; réactions aux fusées éclairantes et leurres ; passages par conduits
  (temps de trajet réel, jamais d'apparition à côté du joueur).
* **Creusement** : grille de cellules rocheuses par chunks (maillage + collision reconstruits à la
  modification), uniquement dans les zones autorisées ; ressources selon la nature de la roche.
* **Base** : bâtiments posés dans l'espace creusé, consommation électrique, effets réels
  (soin, fabrication, recherche, détection, tourelles), raids de fouisseurs.
* **Sauvegarde** : JSON versionné, écriture atomique (fichier temporaire + renommage),
  copie de secours, migration de version, sauvegarde automatique.
* **Qualité graphique** : Économique / Équilibré / Élevé / Ultra (échelle de rendu, ombres,
  densité de particules, distance d'affichage, contours, MSAA).

## 4. Phases
1. Audit + chaîne APK ✅ (ce document)
2. Vertical slice : héros jouable, tactile, combat, ennemi, Dévoreur, fuite/cachette,
   zone souterraine creusable, base, ressources, sauvegarde, shaders, APK.
3. Progression : 6 héros, collection, améliorations, missions, familles d'ennemis.
4. Monde : 5 régions chargées par zones, boss, événements.
5. Optimisation, 6. Tests, 7. Livraison.

## 5. Risques identifiés
* Pas d'appareil Android ni d'émulateur (pas de SDK/KVM) : l'APK est vérifié structurellement
  (signature, alignement, manifeste) mais **l'exécution sur téléphone n'est pas testable ici**.
  Le jeu est testé en exécution réelle sur PC (même code, même renderer GLES3).
* Performance réelle sur mobile non mesurable ici : budgets fixés de façon conservatrice
  (polygones, lumières dynamiques, particules) et options graphiques ajustables.
