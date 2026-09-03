from pathlib import Path

from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.vec_env.vec_monitor import VecMonitor

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv


# Directories used to store the trained model and checkpoints.
MODEL_DIR = Path("models")
CHECKPOINT_DIR = MODEL_DIR / "checkpoints"

MODEL_DIR.mkdir(parents=True, exist_ok=True)
CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)


# Connect Stable-Baselines3 to the running Godot environment.
env = StableBaselinesGodotEnv(
    env_path=None,
    port=11008,
    speedup=10,
)

# Record episode statistics during training.
env = VecMonitor(env)


# Create the PPO model used to learn difficulty-adjustment behaviour.
model = PPO(
    "MultiInputPolicy",
    env,
    verbose=1,
    n_steps=8192,
    batch_size=64,
    n_epochs=10,
    learning_rate=0.0003,
    ent_coef=0.01,
    tensorboard_log="logs/rl_dda_tensorboard",
)


# Save model checkpoints during training.
checkpoint_callback = CheckpointCallback(
    save_freq=10_000,
    save_path=str(CHECKPOINT_DIR),
    name_prefix="rl_dda_ppo_checkpoint",
)


try:
    # Train the PPO model through repeated interaction with Godot.
    model.learn(
        total_timesteps=300_000,
        callback=checkpoint_callback,
    )

except KeyboardInterrupt:
    # Allow training to be stopped manually without losing the current model.
    print("Training interrupted. Saving current model...")

finally:
    # Save the final model and close the Godot environment.
    model.save(MODEL_DIR / "rl_dda_ppo_randomised_stochastic_v1")

    env.close()

    print("Model saved to models/rl_dda_ppo_randomised_stochastic_v1.zip")