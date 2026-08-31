from pathlib import Path

from stable_baselines3 import PPO
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv


MODEL_PATH = Path("models/rl_dda_ppo_randomised_latest_v2.zip")
print(f"Loading model from: {MODEL_PATH.resolve()}")
EVAL_TIMESTEPS = 20_000


env = StableBaselinesGodotEnv(
    env_path=None,
    port=11008,
    speedup=10,
)

model = PPO.load(MODEL_PATH)

obs = env.reset()

try:
    for _ in range(EVAL_TIMESTEPS):
        action, _states = model.predict(obs, deterministic=True)
        obs, reward, done, info = env.step(action)

except KeyboardInterrupt:
    print("Evaluation stopped manually.")

finally:
    env.close()
    print("Evaluation finished.")