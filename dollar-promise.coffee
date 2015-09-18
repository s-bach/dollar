'''#############################################################v1''
#
#                       by Christoph Bach (C)
#
''###############################################################'''

{$} = require './dollar'

isType1 = (obj) ->
	obj &&
		0 <= Array::indexOf.call arguments, obj.constructor, 1

class $Promise extends Promise
	constructor: () ->
		fn = $ arguments...
		fn.exec = fn.new if isType1 @, $Promise
		re = new Promise (res, rej) ->
			fn (err, val) ->
				if err? then rej err else res val
		Object.setPrototypeOf re, $Promise::
		return re

module.exports = {$Promise}