require 'clamp'
require 'colorize'
require 'helpers/common'
require 'helpers/actions'

Clamp.allow_options_after_parameters = true

module Ticket
  class NotFound < StandardError; end

  class Command < Clamp::Command
    include CommonHelpers
  end
end

require 'helpers/ticket/config'
require 'helpers/ticket/info'
