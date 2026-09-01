from pathlib import Path

from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.vec_env.vec_monitor import VecMonitor

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv


MODEL_DIR = Path("models")
CHECKPOINT_DIR = MODEL_DIR / "checkpoints"

MODEL_DIR.mkdir(parents=True, exist_ok=True)
CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)


env = StableBaselinesGodotEnv(
    env_path=None,
    port=11008,
    speedup=10,
)

env = VecMonitor(env)

model = PPO(
    "MultiInputPolicy",
    env,
    verbose=1,
    n_steps=8192,      # Increased from 64. Collects ~2.2 full episodes before updating
    batch_size=64,     # The subset size used during the network update
    n_epochs=10,       # Number of passes over the buffer (default is 10)
    learning_rate=0.0003,
    ent_coef=0.01,     # Adds 1% entropy to force the agent to explore different difficulties
    tensorboard_log="logs/rl_dda_tensorboard",
)

checkpoint_callback = CheckpointCallback(
    save_freq=10_000,
    save_path=str(CHECKPOINT_DIR),
    name_prefix="rl_dda_ppo_checkpoint",
)

try:
    model.learn(
        total_timesteps=300_000,
        callback=checkpoint_callback,
    )

except KeyboardInterrupt:
    print("Training interrupted. Saving current model...")

finally:
    model.save(MODEL_DIR / "rl_dda_ppo_randomised_stochastic_v1")
    env.close()
    print("Model saved to models/rl_dda_ppo_randomised_stochastic_v1.zip")