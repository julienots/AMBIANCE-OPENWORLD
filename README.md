# SYMBIOTE: ABYSS — SuperEssence studio

Jeu d'action-aventure cartoon 3D pour Android (Godot 4.5.1, rendu OpenGL ES 3).
Super-héros, symbiotes horrifiques, monde ouvert et base souterraine creusable.

## Version 0.1.1 — première version jouable (vertical slice)

0.1.1 : corrige l’absence de joystick et de boutons sur téléphone (le calque tactile avait une
taille nulle) ; joystick désormais toujours visible ; icône d’objet corrigée ; test automatisé
par événements tactiles réels (`tools/play_test.sh city touch`).

### Installer sur Android
1. Copier `SymbioteAbyss-0.1.1.apk` sur le téléphone.
2. Autoriser l'installation d'applications de sources inconnues (Paramètres › Sécurité,
   ou à l'ouverture du fichier).
3. Ouvrir l'APK et installer. Android 7.0 (API 24) ou plus récent, processeur ARM 32 ou 64 bits.

L'APK est signé avec une clé de débogage (signatures v1 + v2) : il s'installe directement,
mais n'est pas destiné au Play Store.

### Ce qui fonctionne dans cette version (testé en exécution réelle)
- Démarrage : logo SuperEssence animé, écran titre, préchargement réel.
- Menu principal avec héros en 3D, nouvelle partie / continuer, options.
- **La Mégapole abandonnée** (≈ 280 × 280 m) : rues, ~70 bâtiments, magasins explorables,
  station de métro souterraine, toits accessibles par échelles, zone contaminée, refuge.
- **Contrôles tactiles** : joystick dynamique, caméra au doigt, attaque (appui long = attaque
  lourde), esquive, 3 pouvoirs, ultime, interaction contextuelle, objets, accroupi, lampe ;
  disposition personnalisable, taille et opacité réglables.
- **Combat** : combos, attaque lourde, esquive avec esquive parfaite et contre-attaque au
  ralenti, pouvoirs et ultimes des héros, statuts (brûlure, étourdissement, marque…),
  points faibles, exécutions, captures.
- **Créatures** : rampants (embuscades, peur de la lumière), traqueurs (suivent à distance,
  frappent dans le dos), imitateurs (déguisés en survivants), colosses (charges, frappes au sol
  télégraphiées, cœur exposé). Perception réelle : vue (ligne de vue), bruit, lumière.
- **Furtivité** : bruit des pas, visibilité selon accroupi/lumière/lampe, cachettes, fusées,
  leurres, fumigènes.
- **Base souterraine** : creusement réel de la roche (terre, pierre, minerai, cristaux,
  alliage), placement des installations, énergie, attaques de fouisseurs qui creusent
  vraiment des tunnels vers la base, tourelles, pièges, parois renforcées.
- Collection de 8 héros, arbre de compétences, rangs, équipement, apparences, codex,
  recherche, atelier, missions de la campagne de la Mégapole.
- Sauvegarde locale robuste (écriture atomique, somme de contrôle, copie de secours,
  migration de version) et sauvegarde automatique.
- 4 niveaux graphiques (Économique, Équilibré, Élevé, Ultra) et réglages audio/horreur.

### Pas encore disponible (prochaines versions)
- Régions **Forêt contaminée, Complexe scientifique, Profondeurs, Zone interdite** : les
  passages sont visibles mais indiqués « en construction ».
- Le **Dévoreur** (IA écrite : patrouille, traque accélérée, conduits, portes, fouille des
  cachettes) apparaîtra avec le Complexe scientifique.
- Les 4 boss (scripts de base prêts, arènes à construire).

### Limites connues
- Aucun téléphone ni émulateur n'était disponible pendant le développement : le jeu a été
  testé sur PC avec le même moteur et le même rendu, et l'APK a été vérifié (signature,
  alignement, contenu), mais **les performances sur téléphone n'ont pas pu être mesurées**.
  Si le jeu est lent, choisir « Économique » dans Options › Graphismes.
- Textures non compressées pour GPU mobile (compatibles partout, un peu plus de mémoire).

## Développement

| Dossier | Contenu |
|---|---|
| `game/` | Projet Godot (scènes, scripts GDScript, shaders, assets générés) |
| `tools/assetgen/` | Génération des personnages et créatures (Blender en Python) |
| `tools/audiogen/` | Synthèse de tous les sons et musiques |
| `tools/branding/`, `tools/texgen/` | Logo, icônes, textures procédurales |
| `tools/apksigner/` | Signature APK (v1 + v2) sans SDK Google |
| `docs/PLAN_TECHNIQUE.md` | Audit et plan technique |

```bash
tools/setup_toolchain.sh          # Godot 4.5.1, templates, Blender (bpy), kit de signature
tools/build_apk.sh                # → dist/SymbioteAbyss-<version>.apk (vérifié)
tools/play_test.sh city basic     # test automatisé jouable + captures d'écran
tools/play_test.sh base base      # test creusement / construction / attaque
tools/play_test.sh city flow      # démarrage → menu → partie → menus
tools/play_test.sh city touch     # contrôles par vrais événements tactiles
```

Polices : Luckiest Guy (Apache 2.0), Nunito (OFL). Tous les modèles, sons, musiques,
textures et icônes sont générés par les scripts du dépôt.
