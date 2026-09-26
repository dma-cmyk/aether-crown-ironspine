// Long loops run in the browser's media player so a busy Godot Web frame cannot
// starve the audio mixer. Short game effects remain in Godot's Sample backend.
window.AetherAudio = (() => {
  const tracks = {
    music_battle: { gain: Math.pow(10, -4 / 20), category: "music" },
    amb_wind: { gain: Math.pow(10, -14 / 20), category: "sfx" },
    amb_battle: { gain: Math.pow(10, -20 / 20), category: "sfx" },
  };
  const wanted = new Set();
  let master = 0.8;
  let music = 0.55;
  let sfx = 0.85;
  let fade = 1;
  let fadeFrame = 0;
  let pausedByGame = false;

  function element(id) {
    const track = tracks[id];
    if (!track) return null;
    if (!track.audio) {
      const audio = new Audio(new URL(`audio/${id}.mp3`, document.baseURI));
      audio.loop = true;
      audio.preload = "auto";
      audio.addEventListener("error", () => console.error(`Audio unavailable: ${id}`));
      track.audio = audio;
    }
    return track.audio;
  }

  function refresh() {
    for (const track of Object.values(tracks)) {
      if (!track.audio) continue;
      const category = track.category === "music" ? music * fade : sfx;
      track.audio.volume = Math.max(0, Math.min(1, track.gain * master * category));
    }
  }

  function resume() {
    if (document.hidden || pausedByGame) return;
    for (const id of wanted) {
      const audio = element(id);
      if (audio.paused) audio.play().catch(() => {});
    }
  }

  document.addEventListener("pointerdown", resume, { passive: true });
  document.addEventListener("keydown", resume);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      for (const track of Object.values(tracks)) track.audio?.pause();
    } else {
      resume();
    }
  });

  return {
    play(id) {
      if (!tracks[id]) return;
      wanted.add(id);
      element(id);
      refresh();
      resume();
    },
    stop(id) {
      wanted.delete(id);
      const audio = tracks[id]?.audio;
      if (audio) {
        audio.pause();
        audio.currentTime = 0;
      }
    },
    pause(on) {
      pausedByGame = on;
      if (on) {
        for (const track of Object.values(tracks)) track.audio?.pause();
      } else {
        resume();
      }
    },
    setLevels(nextMaster, nextMusic, nextSfx) {
      master = nextMaster;
      music = nextMusic;
      sfx = nextSfx;
      refresh();
    },
    fadeTo(target, durationMs) {
      cancelAnimationFrame(fadeFrame);
      const from = fade;
      const start = performance.now();
      const step = (now) => {
        fade = from + (target - from) * Math.min(1, (now - start) / durationMs);
        refresh();
        if (Math.abs(fade - target) > 0.001) fadeFrame = requestAnimationFrame(step);
      };
      fadeFrame = requestAnimationFrame(step);
    },
    status() {
      return Object.fromEntries(Object.entries(tracks).map(([id, track]) => [id, {
        wanted: wanted.has(id), playing: Boolean(track.audio && !track.audio.paused),
        volume: track.audio?.volume ?? 0, time: track.audio?.currentTime ?? 0,
      }]));
    },
  };
})();
