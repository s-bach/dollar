'''#############################################################v1''
#
#                     The dollar function ($)
#                       by Christoph Bach (C)
#
# Usage:
	 do $ () ->
		 console.log 'Wer a sagt muss auch...'
		 yield $ (cb) -> setTimeout cb, 1000
		 console.log '... b sagen!'
#
''###############################################################'''

assert = require 'assert'

GeneratorFunction = (->yield 0).constructor if !GeneratorFunction?
Generator = (do->yield 0).constructor if !Generator?

class PromiseError
	constructor: (@f) ->
		Error.captureStackTrace @, PromiseError
	toString: () ->
		@file + ':42\n          throw promiseError;\n          ^\nPromiseError: Promise was rejected! Cause: ' + @message
	print: (@message) ->
		promiseError = if @message instanceof Error
			@message.toString = () -> @message
			@message
		else
			@
		setImmediate () ->
			throw promiseError
			process.stderr.write '\n' + promiseError.stack + '\n' unless process.emit 'uncaughtException', promiseError

Error.prepareStackTrace = do () ->
	prepareStackTrace = Error.prepareStackTrace
	(error, structuredStackTrace) ->
		if error.constructor == PromiseError
			assert error.f == structuredStackTrace[0].getFunction()
			error.file = structuredStackTrace[0].getFileName()
			structuredStackTrace = structuredStackTrace.slice 1
		prepareStackTrace error, structuredStackTrace

class $Callable3
	constructor: () ->
		g = (value, done) ->
			if done
				if typeof f.cb == 'function'
					f.done = true
					f.cb null, value
				return
			unless typeof value == 'function'
				# Promise support
				if typeof value.then == 'function'
					promiseError = new PromiseError f
					promiseDone = false
					fulfill = (val) ->
						return if promiseDone
						promiseDone = true
						try
							try
								{value, done} = f.g.next val
							catch e
								throw e unless f.cb?
								f.done = true
								f.cb e
								return
							g value, done
						catch e
							f.done = true
							promiseError.print e
					reject = (err) ->
						return if promiseDone
						promiseDone = true
						try
							try
								{value, done} = f.g.throw err
							catch e
								throw e unless f.cb?
								f.done = true
								f.cb e
								return
							g value, done
						catch e
							f.done = true
							promiseError.print e
					try
						value.then fulfill, reject
					catch e
						reject e
					return
				console.log "Missing dollar while using yield."
				f new Error "Missing dollar while using yield."
				return
			if value.constructor == GeneratorFunction
				value = $ value
			try
				f.re = value f
			catch err
				throw err if f.done
				try
					{value, done} = f.g.throw err
				catch e
					throw e unless f.cb?
					f.done = true
					f.cb e
					return
				g value, done
			return
		f = (err, val) ->
			try
				{value, done} = if err?
					f.g.throw err
				else
					if val?
						f.g.next val
					else
						f.g.next f.re
			catch e
				throw e unless f.cb?
				f.done = true
				f.cb e
				return
			g value, done
		return f

delay = (duration, cb) -> setTimeout cb, duration

class $ extends Function
	constructor: () ->
		args1 = arguments
		unless typeof args1[0] == 'function'
			throw new Error 'The first parameter must be callable.'
		proto = Object.getPrototypeOf args1[0]
		unless args1[0].constructor == Function && Function:: == proto || args1[0].constructor == GeneratorFunction && GeneratorFunction:: == proto
			throw new Error 'The first parameter must be a Function or a GeneratorFunction.'
		if args1.length == 2 && args1[0] == setTimeout
			args1[0] = delay
		args1 = Array::slice.call arguments, 0
		#args1 = arguments
		if @.constructor == $
			f = () ->
				args = Array args1.length + arguments.length
				args[i] = v for v, i in args1
				args[args1.length + i] = v for v, i in arguments
				unless args[0].constructor == GeneratorFunction
					return new (Function::bind.apply args[0], args)
				fn = do $Callable3
				if typeof arguments[arguments.length - 1] == 'function'
					fn.cb = arguments[arguments.length - 1]
					args.length--
				fn.g = new (Function::bind.apply args[0], args)
				do fn
				return
			Object.setPrototypeOf f, $::
			return f
		f = () ->
			args = Array args1.length + arguments.length
			args[i] = v for v, i in args1
			args[args1.length + i] = v for v, i in arguments
			unless args[0].constructor == GeneratorFunction
				Function::call.apply args[0], args
				return
			fn = do $Callable3
			if typeof arguments[arguments.length - 1] == 'function'
				fn.cb = arguments[arguments.length - 1]
				args.length--
			fn.g = if @constructor == f
				new (Function::bind.apply args[0], args)
			else
				Function::call.apply args[0], args
			do fn
			return
		Object.setPrototypeOf f, $::
		return f

module.exports = $