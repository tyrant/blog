import { Application } from "@hotwired/stimulus";

const application = Application.start();

// Configure Stimulus development experience:
application.debug = false;
window.Stimulus = application;

import DarkModeController from './dark_mode_controller';
application.register('dark-mode', DarkModeController);

import BlizzardForecastController from './blizzard_forecast_controller';
application.register('blizzard-forecast', BlizzardForecastController);

import ConsentIsSexyYoController from '../../components/consent_is_sexy_yo_controller';
application.register('consent-is-sexy-yo', ConsentIsSexyYoController);

import FlashController from '../../components/flash_controller';
application.register('flash', FlashController);

import ModalController from '../../components/modal_controller';
application.register('modal', ModalController);

import NavController from '../../components/nav_controller';
application.register('nav', NavController);

import PostController from '../../components/post_controller';
application.register('post', PostController);

import PrevNekController from '../../components/prev_nek_controller';
application.register('prev-nek', PrevNekController);

export { application };
