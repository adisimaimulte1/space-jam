import math
import pygame


class BetterCursor:
    def __init__(self):
        pygame.mouse.set_visible(False)

        # sound effects
        self.explosion_sfx = pygame.mixer.Sound(
            "assets/sound_effects/cursor/cursor_explosion.mp3"
        )
        self.explosion_sfx.set_volume(0.2)

        self.click_sfx = pygame.mixer.Sound(
            "assets/sound_effects/cursor/cursor_click.mp3"
        )
        self.click_sfx.set_volume(0.8)

        self.tension_sfx = pygame.mixer.Sound(
            "assets/sound_effects/cursor/cursor_tension.mp3"
        )
        self.tension_sfx.set_volume(0.35)
        self.tension_channel = pygame.mixer.Channel(2)
        self.tension_playing = False

        self.pos = pygame.Vector2(pygame.mouse.get_pos())
        self.draw_pos = pygame.Vector2(self.pos)
        self.last_move_dir = pygame.Vector2(1, 0)

        self.default_rotation_offset = 225.0
        self.angle = self.default_rotation_offset

        self.base_scale = 1.2
        self.scale = self.base_scale
        self.target_scale = self.base_scale

        self.click_scale = self.base_scale * 1.15
        self.hold_size = self.base_scale * 1.45
        self.max_hold_scale = self.base_scale * 1.85

        self.shake_offset = pygame.Vector2(0, 0)
        self.shake_strength = 0.0
        self.shake_freq = 45.0

        self.mouse_down = False
        self.prev_mouse_down = False

        self.hold_time = 0.0
        self.fast_hold_duration = 0.22
        self.slow_expand_delay = 0.5
        self.slow_expand_duration = 0.8

        self.exploding = False
        self.explosion_time = 0.0
        self.explosion_duration = 0.35

        self.alt_cursor = False
        self.unlock_flash = 0.0

        self.position_smooth = 20.0
        self.scale_smooth = 24.0
        self.rotation_smooth = 18.0

        self.base_size = 48

        self.cursor_normal = pygame.image.load(
            "assets/images/cursor/cursor_normal.png"
        ).convert_alpha()

        self.cursor_alt = pygame.image.load(
            "assets/images/cursor/cursor_alt.png"
        ).convert_alpha()

    def exp_smooth(self, current, target, sharpness, dt, epsilon=0.001):
        if abs(target - current) < epsilon:
            return target
        return current + (target - current) * (1.0 - math.exp(-sharpness * dt))

    def exp_smooth_vec2(self, current, target, sharpness, dt, epsilon=0.1):
        if current.distance_to(target) < epsilon:
            return pygame.Vector2(target)
        return current.lerp(target, 1.0 - math.exp(-sharpness * dt))

    def lerp_angle(self, current, target, sharpness, dt, epsilon=0.1):
        diff = (target - current + 180) % 360 - 180
        if abs(diff) < epsilon:
            return target
        return current + diff * (1.0 - math.exp(-sharpness * dt))

    def smoothstep(self, t):
        t = max(0.0, min(1.0, t))
        return t * t * (3.0 - 2.0 * t)

    def update(self, dt):
        dt = min(dt, 0.033)

        mouse_pos = pygame.Vector2(pygame.mouse.get_pos())
        delta = mouse_pos - self.pos
        self.pos = mouse_pos

        self.draw_pos = self.exp_smooth_vec2(
            self.draw_pos,
            self.pos,
            self.position_smooth,
            dt
        )

        target_angle = self.angle
        movement_deadzone = 0.5

        if delta.length() > movement_deadzone:
            self.last_move_dir = delta.normalize()
            target_angle = (
                -math.degrees(math.atan2(self.last_move_dir.y, self.last_move_dir.x))
                + self.default_rotation_offset
            )

        self.angle = self.lerp_angle(
            self.angle,
            target_angle,
            self.rotation_smooth,
            dt
        )

        self.prev_mouse_down = self.mouse_down
        self.mouse_down = pygame.mouse.get_pressed()[0]

        just_pressed = self.mouse_down and not self.prev_mouse_down
        just_released = (not self.mouse_down) and self.prev_mouse_down

        if just_pressed and not self.exploding:
            self.target_scale = self.click_scale
            self.click_sfx.stop()
            self.click_sfx.play()

        if self.mouse_down and not self.exploding:
            self.hold_time += dt

            # reset shake by default while holding
            self.shake_strength = 0.0
            self.shake_offset.update(0, 0)

            # Stage 1: fast exponential growth to hold_size
            if self.hold_time < self.slow_expand_delay:
                self.target_scale = self.hold_size

                if self.tension_playing:
                    self.tension_channel.stop()
                    self.tension_playing = False

            # Stage 2: slow expansion from hold_size to max_hold_scale + shaking
            else:
                slow_t = (self.hold_time - self.slow_expand_delay) / self.slow_expand_duration
                slow_t = self.smoothstep(slow_t)

                self.target_scale = self.hold_size + (
                    self.max_hold_scale - self.hold_size
                ) * slow_t

                # shake ramps up during second expand
                self.shake_strength = 1.5 + 6.0 * slow_t
                phase = self.hold_time * self.shake_freq * math.tau
                self.shake_offset.x = math.cos(phase) * self.shake_strength
                self.shake_offset.y = math.sin(phase * 1.37) * self.shake_strength

                if not self.tension_playing:
                    self.tension_channel.play(self.tension_sfx, loops=-1)
                    self.tension_playing = True

                if slow_t >= 1.0:
                    self.scale = self.max_hold_scale
                    self.target_scale = self.max_hold_scale
                    self.trigger_explosion()

        else:
            self.hold_time = 0.0
            self.target_scale = self.base_scale
            self.shake_strength = 0.0
            self.shake_offset.update(0, 0)

            if self.tension_playing:
                self.tension_channel.stop()
                self.tension_playing = False

        if just_released and not self.exploding:
            self.target_scale = self.base_scale

        # Faster smoothing during the first fast charge
        current_scale_smooth = self.scale_smooth
        if self.mouse_down and self.hold_time < self.fast_hold_duration:
            current_scale_smooth = 38.0

        self.scale = self.exp_smooth(
            self.scale,
            self.target_scale,
            current_scale_smooth,
            dt
        )

        if self.exploding:
            self.explosion_time += dt
            t = self.explosion_time / self.explosion_duration

            if t >= 1.0:
                self.exploding = False
                self.explosion_time = 0.0
                self.scale = self.base_scale
                self.target_scale = self.base_scale
                self.alt_cursor = not self.alt_cursor
                self.unlock_flash = 0.25

        if self.unlock_flash > 0:
            self.unlock_flash = max(0, self.unlock_flash - dt)

    def trigger_explosion(self):
        self.exploding = True
        self.explosion_time = 0.0
        self.hold_time = 0.0

        if self.tension_playing:
            self.tension_channel.stop()
            self.tension_playing = False

        self.explosion_sfx.stop()
        self.explosion_sfx.play()

    def draw(self, surface):
        if self.exploding:
            self.draw_explosion(surface)
        else:
            self.draw_cursor(surface)

    def draw_cursor(self, surface):
        image = self.cursor_alt if self.alt_cursor else self.cursor_normal

        scaled_size = max(1, int(self.base_size * self.scale))
        scaled_image = pygame.transform.smoothscale(image, (scaled_size, scaled_size))
        rotated_image = pygame.transform.rotate(scaled_image, self.angle)

        rect = rotated_image.get_rect(
            center=(
                int(self.draw_pos.x + self.shake_offset.x),
                int(self.draw_pos.y + self.shake_offset.y),
            )
        )
        surface.blit(rotated_image, rect)

        if self.unlock_flash > 0:
            alpha = int(255 * (self.unlock_flash / 0.25))
            flash_surface = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
            pygame.draw.circle(
                flash_surface,
                (255, 255, 255, alpha),
                (int(self.draw_pos.x), int(self.draw_pos.y)),
                int(self.base_size * 1.4),
                3
            )
            surface.blit(flash_surface, (0, 0))

    def draw_explosion(self, surface):
        t = min(1.0, self.explosion_time / self.explosion_duration)
        center = pygame.Vector2(self.draw_pos.x, self.draw_pos.y)

        color = (255, 255, 255)

        # Better easing
        ease_out = 1.0 - (1.0 - t) ** 3
        fade = 1.0 - t

        fx = pygame.Surface(surface.get_size(), pygame.SRCALPHA)

        # 1) Bright central flash
        flash_r = int(8 + 42 * ease_out)
        flash_alpha = int(180 * fade)
        pygame.draw.circle(
            fx,
            (*color, flash_alpha),
            (int(center.x), int(center.y)),
            flash_r
        )

        inner_flash_r = int(4 + 18 * ease_out)
        inner_flash_alpha = int(255 * fade)
        pygame.draw.circle(
            fx,
            (255, 255, 255, inner_flash_alpha),
            (int(center.x), int(center.y)),
            inner_flash_r
        )

        # 2) Main shockwave ring
        ring_r = int(14 + 70 * ease_out)
        ring_alpha = int(230 * fade)
        ring_width = max(1, int(5 - 3 * t))
        pygame.draw.circle(
            fx,
            (*color, ring_alpha),
            (int(center.x), int(center.y)),
            ring_r,
            ring_width
        )

        # 3) Secondary softer ring for depth
        ring2_r = int(8 + 40 * ease_out)
        ring2_alpha = int(110 * fade)
        pygame.draw.circle(
            fx,
            (*color, ring2_alpha),
            (int(center.x), int(center.y)),
            ring2_r,
            2
        )

        # 4) Radial streaks
        streak_count = 8
        for i in range(streak_count):
            ang = math.radians(i * (360 / streak_count) + t * 30)
            start_dist = 10 + 12 * ease_out
            end_dist = 26 + 65 * ease_out

            x1 = center.x + math.cos(ang) * start_dist
            y1 = center.y + math.sin(ang) * start_dist
            x2 = center.x + math.cos(ang) * end_dist
            y2 = center.y + math.sin(ang) * end_dist

            pygame.draw.line(
                fx,
                (*color, int(150 * fade)),
                (x1, y1),
                (x2, y2),
                max(1, int(4 - 2 * t))
            )

        # 5) Triangle shard-like particles instead of circles
        shard_count = 10
        for i in range(shard_count):
            ang = math.radians(i * (360 / shard_count) + 18)
            dist = 18 + 55 * ease_out
            px = center.x + math.cos(ang) * dist
            py = center.y + math.sin(ang) * dist

            shard_angle = ang + t * 4.0
            shard_size = max(2, int(8 * fade + 3))

            p1 = (
                px + math.cos(shard_angle) * shard_size,
                py + math.sin(shard_angle) * shard_size
            )
            p2 = (
                px + math.cos(shard_angle + 2.4) * shard_size * 0.7,
                py + math.sin(shard_angle + 2.4) * shard_size * 0.7
            )
            p3 = (
                px + math.cos(shard_angle - 2.4) * shard_size * 0.7,
                py + math.sin(shard_angle - 2.4) * shard_size * 0.7
            )

            pygame.draw.polygon(
                fx,
                (*color, int(190 * fade)),
                [p1, p2, p3]
            )

        surface.blit(fx, (0, 0))