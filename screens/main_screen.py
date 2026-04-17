from screens.screen import *

import pygame
import math


class MainScreen(Screen):
    def __init__(self, game):
        super().__init__(game)
        self.game.music.play("menu_song")

        # cache screen size
        self.screen_w, self.screen_h = self.game.screen.get_size()

        # create background surface
        self.bg_surface = pygame.Surface((self.screen_w, self.screen_h), pygame.SRCALPHA)

        # load texts
        self.prompt_font = pygame.font.Font("assets/fonts/pixel.ttf", 54)
        self.prompt_surface_base = self.prompt_font.render("PRESS SPACE TO PLAY", True, (255, 255, 255))

        # load images
        self.logo_image = pygame.image.load("assets/images/logo/space_jam_logo_white_outline.png").convert_alpha()
        self.bg_void = pygame.image.load("assets/images/backgrounds/main_screen/space_background_void.png").convert_alpha()
        self.bg_stars = pygame.image.load("assets/images/backgrounds/main_screen/space_background_stars.png").convert_alpha()
        self.bg_planets = pygame.image.load("assets/images/backgrounds/main_screen/space_background_planets.png").convert_alpha()
        self.bg_nebula = pygame.image.load("assets/images/backgrounds/main_screen/space_background_nebula.png").convert_alpha()

        # image parameters
        self.logo_scale = 0.7

        # modify loaded images
        self.scaled_logo = pygame.transform.scale(
            self.logo_image,
            (
                int(self.logo_image.get_width() * self.logo_scale),
                int(self.logo_image.get_height() * self.logo_scale),
            )
        )

        # parallax effect parameters
        self.camera_time = 0.0
        self.camera_radius_x = 35
        self.camera_radius_y = 20
        self.camera_speed = 0.1

        self.anim_time = 0.0

        # game enter transition parameters
        self.starting_game = False
        self.start_transition_time = 0.0
        self.start_transition_duration = 1.2

        self.update_layout()


    # parametric functions
    def ease_in_out(self, t):
        t = max(0.0, min(1.0, t))
        return t * t * (3.0 - 2.0 * t)

    def get_camera_offset(self):
        angle = self.camera_time * math.tau * self.camera_speed
        x = math.cos(angle) * self.camera_radius_x
        y = math.sin(angle) * self.camera_radius_y
        return pygame.Vector2(x, y)


    # abstract common method for SCREENS
    def handle_event(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE and not self.starting_game:
                self.starting_game = True
                self.start_transition_time = 0.0
                self.game.music.play_start_sequence_then("game_song")


    # update methods
    def update_layout(self):
        # get the window size
        center_x = self.screen_w // 2
        center_y = self.screen_h // 2

        # logo positioning
        self.logo_pos = (center_x - 20, center_y - 70)
        self.prompt_pos = (center_x, center_y + 350)

        # background scaling
        scale_extra = 64
        scaled_size = (self.screen_w + scale_extra, self.screen_h + scale_extra)

        self.bg_void_scaled = pygame.transform.scale(self.bg_void, scaled_size)
        self.bg_stars_scaled = pygame.transform.scale(self.bg_stars, scaled_size)
        self.bg_planets_scaled = pygame.transform.scale(self.bg_planets, scaled_size)
        self.bg_nebula_scaled = pygame.transform.scale(self.bg_nebula, scaled_size)

    def update(self, dt):
        self.anim_time += dt
        self.camera_time += dt

        if self.starting_game:
            self.start_transition_time += dt
            if self.start_transition_time >= self.start_transition_duration:
                self.start_transition_time = self.start_transition_duration

                # next step:
                # self.game.change_screen(GameScreen(self.game))


    # drawing methods
    def draw_parallax_layer(self, surface, image, camera_offset, depth, extra_offset=(0, 0)):
        offset = camera_offset * depth
        rect = image.get_rect(
            center=(
                self.screen_w // 2 + int(offset.x + extra_offset[0]),
                self.screen_h // 2 + int(offset.y + extra_offset[1]),
            )
        )
        surface.blit(image, rect)

    def draw_pixelated_background(self, surface):
        bg_surface = self.bg_surface
        bg_surface.fill((0, 0, 0, 0))

        camera_offset = self.get_camera_offset()

        t = 0.0
        if self.starting_game:
            t = self.ease_in_out(self.start_transition_time / self.start_transition_duration)

        self.draw_parallax_layer(bg_surface, self.bg_void_scaled, camera_offset, 0.05)
        self.draw_parallax_layer(bg_surface, self.bg_stars_scaled, camera_offset, 0.35)
        self.draw_parallax_layer(bg_surface, self.bg_planets_scaled, camera_offset, 0.65)

        if t < 1.0:
            nebula = self.bg_nebula_scaled.copy()
            nebula.set_alpha(int(255 * (1.0 - t)))
            self.draw_parallax_layer(bg_surface, nebula, camera_offset, 0.95)

        pixel_factor = 4
        small = pygame.transform.scale(
            bg_surface,
            (max(1, self.screen_w // pixel_factor), max(1, self.screen_h // pixel_factor))
        )
        pixelated = pygame.transform.scale(small, (self.screen_w, self.screen_h))

        surface.blit(pixelated, (0, 0))

    def draw(self, surface):
        self.draw_pixelated_background(surface)

        t = 0.0
        if self.starting_game:
            t = self.ease_in_out(self.start_transition_time / self.start_transition_duration)

        # draw the logo
        logo_y_offset = -surface.get_height() * 0.9 * t
        logo_rect = self.scaled_logo.get_rect(
            center=(self.logo_pos[0], self.logo_pos[1] + logo_y_offset)
        )
        surface.blit(self.scaled_logo, logo_rect)

        # draw the PRESS START text
        if not self.starting_game:
            blink_on = int(self.anim_time * 2.2) % 2 == 0
        else:
            blink_on = True

        if blink_on:
            prompt_surface = self.prompt_surface_base.copy()

            if self.starting_game:
                alpha = int(255 * (1.0 - t))
                prompt_surface.set_alpha(alpha)

            prompt_y_offset = 120 * t
            prompt_rect = prompt_surface.get_rect(
                center=(self.prompt_pos[0], self.prompt_pos[1] + prompt_y_offset)
            )

            surface.blit(prompt_surface, prompt_rect)
            surface.blit(prompt_surface, prompt_rect.move(1, 0))
            surface.blit(prompt_surface, prompt_rect.move(0, 1))