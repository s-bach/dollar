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

isType1 = (obj) ->
	obj &&
		0 <= Array::indexOf.call arguments, obj.constructor, 1

isType = (obj) ->
	obj &&
		0 <= (i = Array::indexOf.call arguments, obj.constructor, 1) &&
			arguments[i]:: == Object.getPrototypeOf obj

class PromiseError
	constructor: (@f) ->
		Error.captureStackTrace @, PromiseError
	toString: () ->
		@file + ':42\n          throw promiseError;\n          ^\nPromiseError: Promise was rejected! Cause: ' + @message
	print: (@message) ->
		setImmediate () =>
			process.stderr.write '\n' + @stack + '\n' unless process.emit 'uncaughtException', @

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
		f = (err, val) ->
			assert isType1 f.g, Generator # internal error
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
								f.g.next val
							catch e
								throw e unless f.cb?
								f.done = true
								f.cb e
						catch e
							f.done = true
							promiseError.print e
					reject = (err) ->
						return if promiseDone
						promiseDone = true
						try
							try
								f.g.throw err
							catch e
								throw e unless f.cb?
								f.done = true
								f.cb e
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
			if isType1 value, GeneratorFunction
				value = $ value
			try
				f.re = value f
			catch e
				throw e if f.done
				f e # BUG: this is wrong when throwing a undefined value
			return
		return f

delay = (duration, cb) -> setTimeout cb, duration

class $ extends Function
	constructor: () ->
		unless typeof arguments[0] == 'function'
			throw new Error 'The first parameter must be callable.'
		unless isType arguments[0], Function, GeneratorFunction, $
			throw new Error 'The first parameter must be a Function or a GeneratorFunction.'
		if arguments.length == 2 && arguments[0] == setTimeout
			arguments[0] = delay
		args1 = Array::slice.call arguments, 0
		#args1 = arguments
		if isType1 @, $
			f = () ->
				args = Array args1.length + arguments.length
				args[i] = args1[i] for v, i in args1
				args[args1.length + i] = arguments[i] for v, i in arguments
				unless args[0].constructor == GeneratorFunction
					return new (Function::bind.apply args[0], args)
				fn = do $Callable3
				args.length-- if typeof (fn.cb = arguments[arguments.length - 1]) == 'function'
				fn.g = new (Function::bind.apply args[0], args)
				do fn
				return
			Object.setPrototypeOf f, $::
			return f
		f = () ->
			args = Array args1.length + arguments.length
			args[i] = args1[i] for v, i in args1
			args[args1.length + i] = arguments[i] for v, i in arguments
			unless args[0].constructor == GeneratorFunction
				Function::call.apply args[0], args
				return
			fn = do $Callable3
			args.length-- if typeof (fn.cb = arguments[arguments.length - 1]) == 'function'
			fn.g = if @constructor == f
				new (Function::bind.apply args[0], args)
			else
				Function::call.apply args[0], args
			do fn
			return
		Object.setPrototypeOf f, $::
		return f

module.exports = $
