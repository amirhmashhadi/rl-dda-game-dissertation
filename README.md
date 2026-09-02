# RL-Based Dynamic Difficulty Adjustment in Godot

MSc Data Science dissertation project investigating whether **reinforcement learning can be used for Dynamic Difficulty Adjustment (DDA)** in a Godot game environment.

The project compares three difficulty systems:

- Static difficulty
- Rule-based DDA
- Reinforcement Learning-based DDA

The RL system uses **Proximal Policy Optimisation (PPO)** through Stable-Baselines3 and communicates with Godot using **Godot RL Agents**.

## Project Overview

The prototype is a 2D survival environment in which difficulty affects gameplay parameters such as projectile speed, fire rate, damage, and accuracy.

Five simulated player profiles are used for controlled evaluation:

- Beginner
- Intermediate
- Skilled
- Inconsistent
- Improving

The RL agent observes gameplay performance and selects one of three actions:

- Decrease difficulty
- Maintain difficulty
- Increase difficulty

Final evaluation compares all three difficulty systems across the same simulated player profiles.

## Technologies

- Godot 4.1.4
- GDScript
- Python 3.10
- Stable-Baselines3
- Godot RL Agents
- PPO
- pandas
- matplotlib
- Jupyter

## Repository Structure

```text
rl-dda-game-dissertation/
├── godot_project/
│   └── game_project/       # Godot game and DDA systems
├── rl_training/            # RL training/evaluation scripts
├── notebooks/              # Experiment analysis
├── data/
│   └── processed/          # Combined analysis datasets
├── results/
│   ├── figures/            # Generated plots
│   └── tables/             # Generated result tables
├── requirements.txt
└── README.md
```

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/bigladamir/rl-dda-game-dissertation.git
cd rl-dda-game-dissertation
```

### 2. Install Python 3.10

Download Python 3.10 from:

https://www.python.org/downloads/

### 3. Create a virtual environment

#### macOS / Linux

```bash
python3.10 -m venv .venv
source .venv/bin/activate
```

#### Windows PowerShell

```powershell
py -3.10 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 4. Install dependencies

```bash
pip install -r requirements.txt
```

### 5. Open the Godot project

Open:

```text
godot_project/game_project/project.godot
```

using **Godot 4.1.4**.

Godot 4.1.4 release:

https://godotengine.org/article/maintenance-release-godot-4-2-2-and-4-1-4/

## Experiment Design

Each difficulty system is evaluated using the same five simulated player profiles.

For the final evaluation:

```text
30 runs × 5 profiles = 150 episodes per system
```

Across all three systems:

```text
450 final evaluation episodes
```

Each episode lasts a maximum of 60 seconds.

Logged metrics include:

- Survival time
- Death/failure rate
- Health remaining
- Hits taken
- Average difficulty
- Final difficulty
- Difficulty changes
- Time spent within the target balance range

The final PPO evaluation uses **stochastic policy sampling**, which preserved the adaptive behaviour learned during training.

## Analysis

Experimental analysis is performed in the Jupyter notebooks under:

```text
notebooks/
```

Generated plots and tables are saved to:

```text
results/figures/
results/tables/
```

## Key Dependencies

- [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents)
- [Stable-Baselines3](https://stable-baselines3.readthedocs.io/)
- [Godot Engine](https://godotengine.org/)

## Dissertation

This repository accompanies an MSc Data Science dissertation evaluating the practical use of reinforcement learning for Dynamic Difficulty Adjustment in a Godot-based game using simulated player behaviours.