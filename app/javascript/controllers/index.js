// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import FormSubmitController from "./form_submit_controller"
eagerLoadControllersFrom("controllers", application)
application.register("form-submit", FormSubmitController)
