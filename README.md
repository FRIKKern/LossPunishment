# LossPunishment

A World of Warcraft addon that turns PvP losses into exercise opportunities!!

## Description

LossPunishment automatically prompts you to do physical exercises when you lose in PvP content like Battlegrounds or Arenas. Turn your defeats into victories for your health!

> **Note:** This addon is designed for **Retail** World of Warcraft only.

### Features

- **Exercise Prompts**: Get prompted to do exercises (Pushups, Squats, Situps) after losing in PvP
- **Customization**: Enable/disable specific exercise types
- **Statistics Tracking**: View detailed statistics on completed exercises
- **Time-Based Stats**: See your exercise progress by day, week, month, and all-time

## Installation

1. Download the latest release from the [Releases](https://github.com/Frikkern/LossPunishment/releases) page
2. Extract the `LossPunishment` folder to your WoW addons directory:
   - `World of Warcraft\_retail_\Interface\AddOns\`
3. Start/Restart World of Warcraft

## Usage

### Commands

- `/lp` or `/losspunish` - Shows available commands
- `/lp options` or `/lp config` - Opens the settings panel
- `/lp stats` - Shows your exercise statistics
- `/lp history` - Opens the exercise history window

### Options Panel

Access the options panel via the command `/lp options` or through the Interface → AddOns menu. From here you can:

- Enable/disable specific exercises
- View exercise statistics by time period
- Access detailed exercise history
- Reset statistics if desired

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Deployment

This project includes deployment scripts to automate the release process:

### Windows (PowerShell)

```powershell
# Create a patch release (increment third number: 0.1.0 -> 0.1.1)
.\deploy.ps1

# Create a minor release (increment second number: 0.1.0 -> 0.2.0)
.\deploy.ps1 -VersionIncrement "minor"

# Create a major release (increment first number: 0.1.0 -> 1.0.0)
.\deploy.ps1 -VersionIncrement "major"

# Customize commit message
.\deploy.ps1 -CommitMessage "Added new features"
```

### Linux/macOS (Bash)

```bash
# Make the script executable
chmod +x deploy.sh

# Create a patch release (increment third number: 0.1.0 -> 0.1.1)
./deploy.sh

# Create a minor release (increment second number: 0.1.0 -> 0.2.0)
./deploy.sh --minor

# Create a major release (increment first number: 0.1.0 -> 1.0.0)
./deploy.sh --major

# Customize commit message
./deploy.sh -m "Added new features"
```

The scripts will:
1. Update the version number in the TOC file
2. Commit all changes
3. Create a version tag
4. Push to GitHub
5. Trigger the GitHub Actions workflow to create a release

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by the health benefits of taking short exercise breaks
- Thanks to all WoW players who value both in-game and real-life fitness 