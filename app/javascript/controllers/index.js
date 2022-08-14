import { Application } from "stimulus";
import { definitionsFromContext } from "stimulus/webpack-helpers";

const application = Application.start();
const context = require.context("controllers", true, /\.js$/);
const contextComponents = require.context("../../components", true, /_controller\.js$/);
application.load(
  definitionsFromContext(context).concat(
    definitionsFromContext(contextComponents)
  )
);
