import pygame

from managers.cursor_manager import *
from managers.music_manager import *
from screens.main_screen import *
from config import *


class Game:
    def __init__(self):
        pygame.init()
        pygame.mixer.init()
        pygame.display.set_caption(".|.")

        self.screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)

        self.cursor = BetterCursor()
        self.music = MusicManager()

        self.clock = pygame.time.Clock()
        self.running = True
        self.FPS = 60

        self.current_screen = MainScreen(self)
        self.current_screen.on_enter()


    # change screen sequence
    def change_screen(self, new_screen):
        self.current_screen.on_exit()
        self.current_screen = new_screen
        self.current_screen.on_enter()



    def quit(self):
        self.running = False

    def run(self):
        while self.running:
            dt = self.clock.tick(self.FPS) / 1000.0

            for event in pygame.event.get():
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.quit()

                    elif event.key == pygame.K_m:
                        self.music.toggle_mute()

                    elif event.key == pygame.K_SPACE and not self.current_screen.starting_game:
                        self.current_screen.starting_game = True
                        self.start_transition_time = 0.0
                        self.music.play_start_sequence_then("game_song")

                else:
                    self.current_screen.handle_event(event)

            self.current_screen.update(dt)
            self.cursor.update(dt)
            self.music.update(dt)

            self.current_screen.draw(self.screen)
            self.cursor.draw(self.screen)
            self.music.draw(self.screen)

            pygame.display.flip()