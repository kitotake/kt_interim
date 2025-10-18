# 🏢 Script Intérim Complet - FiveM

Script d'intérim moderne et complet pour FiveM avec ox_lib et ox_inventory.

## 📋 Fonctionnalités

### Jobs Disponibles

1. **🏗️ Construction** - Collecte et dépôt de briques
2. **🧹 Nettoyage** - Collecte de poubelles aux différents points
3. **📦 Livraison** - Livraison de colis en ville
4. **🏪 Logistique Magasin** - Déplacement de cartons en entrepôt
5. **🚕 Taxi** - Transport de clients (salaire basé sur la distance)
6. **🚛 Camionneur** - Transport de marchandises par poids lourd

### Systèmes Avancés

- ✅ **Système de réputation** - Montez en niveau en complétant des jobs
- ✅ **Bonus de productivité** - Bonus tous les 5 jobs complétés
- ✅ **Quêtes journalières** - 3 missions quotidiennes avec récompenses bonus
- ✅ **Salaire dynamique** - Les salaires varient selon l'affluence
- ✅ **Anti-cheat intégré** - Détection des tentatives de triche
- ✅ **Système de cooldown** - Empêche le spam de missions
- ✅ **Statistiques** - Trackez vos performances
- ✅ **Support MySQL** - Sauvegarde de toutes les données
- ✅ **Logs Discord** (optionnel) - Surveillance des activités

## 🔧 Installation

### Prérequis

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [oxmysql](https://github.com/overextended/oxmysql)
- ESX ou QB-Core (optionnel, pour l'argent)

### Étapes d'installation

1. **Télécharger le script**
   ```bash
   cd resources
   git clone [votre-repo] interim
   ```

2. **Ajouter les items dans ox_inventory**
   
   Ouvrez `ox_inventory/data/items.lua` et ajoutez :
   
   ```lua
   ['construction_brick'] = {
       label = 'Brique de construction',
       weight = 500,
       stack = true,
       close = true,
       description = 'Une brique de construction lourde'
   },
   
   ['trash_bag'] = {
       label = 'Sac poubelle',
       weight = 200,
       stack = true,
       close = true,
       description = 'Un sac poubelle à déposer'
   },
   
   ['delivery_package'] = {
       label = 'Colis',
       weight = 300,
       stack = true,
       close = true,
       description = 'Un colis à livrer'
   },
   
   ['shop_box'] = {
       label = 'Carton de marchandise',
       weight = 400,
       stack = true,
       close = true,
       description = 'Un carton de marchandise'
   },
   
   ['truck_crate'] = {
       label = 'Caisse de marchandise',
       weight = 800,
       stack = true,
       close = true,
       description = 'Une grosse caisse de marchandise'
   }
   ```

3. **Configurer le script**
   
   Éditez `config/config_global.lua` selon vos besoins :
   - Positions des jobs
   - Salaires
   - Modèles de véhicules
   - Points de collecte/livraison

4. **Ajouter dans server.cfg**
   ```
   ensure ox_lib
   ensure ox_inventory
   ensure oxmysql
   ensure interim
   ```

5. **Redémarrer le serveur**

## ⚙️ Configuration

### Configuration générale

```lua
Config.UseOxTarget = true -- Utiliser ox_target pour l'interaction
Config.Notification = 'ox_lib' -- Type de notification (ox_lib, esx, qb)
Config.ProgressBar = 'ox_lib' -- Type de progress bar
```

### Exemple de configuration d'un job

```lua
construction = {
    enabled = true,
    label = "Ouvrier de construction",
    description = "Collectez et déposez des briques sur le chantier",
    salary = 150, -- Salaire de base
    blip = {
        coords = vector3(x, y, z),
        sprite = 478,
        color = 47,
        scale = 0.8
    },
    npc = {
        coords = vector4(x, y, z, heading),
        model = 's_m_y_construct_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    },
    -- ... autres configurations
}
```

## 📊 Commandes

### Joueurs

- `/cancelinterim` - Annuler le job en cours
- `/interimstats` - Voir ses statistiques
- `/interimrep` - Voir sa réputation
- `/interimquests` - Voir les quêtes du jour

### Admins (Console uniquement)

- `/interimstats [id]` - Voir les stats d'un joueur
- `/interimreset [id]` - Reset le job actif d'un joueur

## 🔒 Système Anti-Cheat

Le script inclut plusieurs protections :

- ✅ Vérification de la distance (le joueur doit être proche des points)
- ✅ Vérification des items (le joueur doit avoir les items requis)
- ✅ Système de cooldown (empêche le spam)
- ✅ Vérification des récompenses (détecte les montants anormaux)
- ✅ Système de pénalités (ban temporaire après 5 infractions)

## 📈 Système de Réputation

Les joueurs gagnent de l'XP à chaque job complété :
- XP gagné = Salaire ÷ 15
- Level up tous les 100 XP
- Bonus d'argent à chaque montée de niveau

## 🎯 Quêtes Journalières

3 quêtes générées chaque jour :
- Complétez X fois un job spécifique
- Récompense : 120% du salaire normal × nombre requis
- Reset automatique toutes les 24h

## 💰 Salaire Dynamique

Les salaires varient selon l'affluence :
- **< 5 completions/h** : +30%
- **5-10 completions/h** : +15%
- **10-20 completions/h** : Normal
- **> 20 completions/h** : -15%

## 📦 Exports

### Client

```lua
-- Obtenir le job actif
local jobName, jobConfig = exports['kt_interim']:GetActiveJob()

-- Vérifier si un job est actif
local isActive = exports['kt_interim']:IsJobActive()

-- Annuler le job actif
exports['kt_interim']:CancelJob()
```

### Server

```lua
-- Vérifier si un joueur a un job actif
local hasJob = exports['kt_interim']:IsPlayerOnJob(source)

-- Obtenir le job actif d'un joueur
local jobName = exports['kt_interim']:GetPlayerActiveJob(source)

-- Obtenir la réputation d'un joueur
local rep = exports['kt_interim']:GetPlayerReputation(identifier)
```

## 🛠️ Support & Personnalisation

### Ajouter un nouveau job

1. Ajoutez la configuration dans `config/config_global.lua`
2. Ajoutez la logique dans `client/jobs.lua`
3. Ajoutez la validation dans `server/jobs.lua` (optionnel)

### Exemple de nouveau job

```lua
-- config/config_global.lua
my_new_job = {
    enabled = true,
    label = "Mon nouveau job",
    description = "Description du job",
    salary = 200,
    -- ... configuration complète
}

-- client/jobs.lua
function StartMyNewJob(config)
    -- Votre logique ici
end

-- Dans RegisterNetEvent('kt_interim:startJob')
elseif jobName == 'my_new_job' then
    StartMyNewJob(jobConfig)
```

## 📝 Base de données

Le script crée automatiquement la table suivante :

```sql
CREATE TABLE `kt_interim` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `job_type` VARCHAR(50) NOT NULL,
    `data` TEXT,
    `reward` INT DEFAULT 0,
    `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_job_type` (`job_type`)
)
```

## 🐛 Problèmes connus

- Si ox_target ne fonctionne pas, désactivez-le dans la config (`Config.UseOxTarget = false`)
- Assurez-vous que tous les modèles de véhicules/peds existent dans votre serveur
- Vérifiez que les coordonnées sont correctes pour votre map

## 📄 Licence

Ce script est fourni "tel quel" sans garantie. Libre d'utilisation et modification.

## 🤝 Crédits

- ox_lib - Overextended
- ox_inventory - Overextended
- Développé avec ❤️ pour la communauté FiveM

---

**Version:** 1.0.0  
**Dernière mise à jour:** 2025