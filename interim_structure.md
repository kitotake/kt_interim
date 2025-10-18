# 📁 Structure du Projet Intérim

```
interim/
│
├── 📄 fxmanifest.lua           # Manifest principal du resource
├── 📄 README.md                # Documentation complète
├── 📄 interim.sql              # Script SQL pour la base de données
├── 📄 STRUCTURE.md             # Ce fichier
│
├── 📁 config/
│   └── 📄 config_global.lua    # Configuration globale de tous les jobs
│
├── 📁 client/
│   ├── 📄 utils.lua            # Fonctions utilitaires côté client
│   ├── 📄 main.lua             # Fichier principal client (blips, NPCs, menus)
│   └── 📄 jobs.lua             # Logique de chaque job côté client
│
└── 📁 server/
    ├── 📄 utils.lua            # Fonctions utilitaires côté serveur
    ├── 📄 main.lua             # Fichier principal serveur (events, récompenses)
    └── 📄 jobs.lua             # Validations et systèmes avancés serveur
```

