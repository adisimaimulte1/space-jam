import pygame


class MusicManager:
    def __init__(self):
        self.current_track = None
        self.volume = 0.5
        self.is_muted = False

        self.icon_timer = 0.0
        self.icon_duration = 1.0

        raw_volume = pygame.image.load(
            "assets/images/buttons/volume/volume_normal.png"
        ).convert_alpha()

        raw_muted = pygame.image.load(
            "assets/images/buttons/volume/volume_muted.png"
        ).convert_alpha()

        scale = 4

        self.icon_volume = pygame.transform.scale(
            raw_volume,
            (int(raw_volume.get_width() * scale), int(raw_volume.get_height() * scale))
        )

        self.icon_muted = pygame.transform.scale(
            raw_muted,
            (int(raw_muted.get_width() * scale), int(raw_muted.get_height() * scale))
        )

        self.pending_track = None
        self.pending_loop = True
        self.pending_delay = 0.0

        self.start_sfx = pygame.mixer.Sound(
            "assets/sound_effects/transitions/entering_game.wav"
        )
        self.start_sfx_length = self.start_sfx.get_length()
        self.sfx_channel = pygame.mixer.Channel(1)

        self.screen_w, self.screen_h = pygame.display.get_surface().get_size()
        self.icon_topright = (self.screen_w - 30, 30)

        self._icon_temp = pygame.Surface(
            self.icon_volume.get_size(),
            pygame.SRCALPHA
        )

    def _applied_volume(self):
        return 0.0 if self.is_muted else self.volume


    # base methods
    def play(self, track_name, loop=True, fade_ms=500, force_restart=False):
        if self.current_track == track_name and not force_restart:
            return

        if pygame.mixer.music.get_busy():
            pygame.mixer.music.fadeout(fade_ms)

        pygame.mixer.music.load(f"assets/music/{track_name}.mp3")
        pygame.mixer.music.set_volume(self._applied_volume())
        pygame.mixer.music.play(-1 if loop else 0, fade_ms=fade_ms)

        self.current_track = track_name

    def stop(self, fade_ms=500):
        pygame.mixer.music.fadeout(fade_ms)
        self.current_track = None


    # aux methods
    def set_volume(self, volume):
        self.volume = volume
        if not self.is_muted:
            pygame.mixer.music.set_volume(volume)

    def toggle_mute(self):
        self.is_muted = not self.is_muted
        pygame.mixer.music.set_volume(self._applied_volume())
        self.sfx_channel.set_volume(self._applied_volume())
        self.icon_timer = self.icon_duration

    def play_start_sequence_then(self, next_track_name, next_loop=True, music_fade_ms=400):
        if self.pending_track is not None:
            return

        self.stop(fade_ms=music_fade_ms)

        self.sfx_channel.stop()
        self.sfx_channel.set_volume(self._applied_volume())
        self.sfx_channel.play(self.start_sfx)

        self.pending_track = next_track_name
        self.pending_loop = next_loop
        self.pending_delay = self.start_sfx_length


    # update methods
    def update(self, dt):
        if self.icon_timer > 0:
            self.icon_timer = max(0.0, self.icon_timer - dt)

        if self.pending_track is not None:
            self.pending_delay -= dt
            if self.pending_delay <= 0:
                track = self.pending_track
                loop = self.pending_loop

                self.pending_track = None
                self.pending_loop = True
                self.pending_delay = 0.0

                self.play(track, loop=loop, fade_ms=0, force_restart=True)


    # draw methods
    def draw(self, surface):
        if self.icon_timer <= 0:
            return

        # update opacity
        alpha = int(255 * (self.icon_timer / self.icon_duration))
        icon = self.icon_volume if self.is_muted else self.icon_muted

        self._icon_temp.fill((0, 0, 0, 0))
        self._icon_temp.blit(icon, (0, 0))
        self._icon_temp.set_alpha(alpha)

        rect = self._icon_temp.get_rect(topright=self.icon_topright)
        surface.blit(self._icon_temp, rect)