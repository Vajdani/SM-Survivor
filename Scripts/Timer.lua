---@class Timer
---@field ticks number The timer's length.
---@field count number The progress of the timer.
Timer = class( nil )

function Timer:start(ticks)
	self.ticks = ticks or 0
	self.count = 0
end

function Timer:complete()
	self.count = self.ticks
end

function Timer:reset()
	self.ticks = self.ticks or -1
	self.count = 0
end

function Timer:stop()
	self.ticks = -1
	self.count = 0
end

function Timer:tick()
	self.count = self.count + 1
end

function Timer:done()
	return self.ticks >= 0 and self.count >= self.ticks
end
