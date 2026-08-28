from stable_baselines3 import PPO
from stable_baselines3.common.vec_env.vec_monitor import VecMonitor

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv


env = StableBaselinesGodotEnv(
    env_path=None,     # None means in-editor training
    port=11008,
    speedup=5,
)

env = VecMonitor(env)

model = PPO(
    "MultiInputPolicy",
    env,
    verbose=1,
    n_steps=64,
    batch_size=64,
    learning_rate=0.0003,
    tensorboard_log="logs/rl_dda_tensorboard",
)

model.learn(total_timesteps=10_000)

model.save("models/rl_dda_ppo_intermediate")

env.close()