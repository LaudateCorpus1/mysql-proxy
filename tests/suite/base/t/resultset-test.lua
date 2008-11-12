--[[ $%BEGINLICENSE%$
 Copyright (C) 2008 MySQL AB, 2008 Sun Microsystems, Inc

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2 of the License.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 $%ENDLICENSE%$ --]]
local chassis = require("chassis")
local proto   = require("mysql.proto")

local my_lovely_packet

function read_query(packet)
	proxy.queries:append(1, packet, { resultset_is_needed = true })

	my_lovely_packet = packet

	return proxy.PROXY_SEND_QUERY
end

function read_query_result(inj)
	assert(inj)
	assert(inj.id == 1) -- the id we assigned above
	assert(inj.query == my_lovely_packet) -- the id we assigned above

	assert(inj.query_time > 0)
	assert(inj.response_time > 0)

	local res = assert(inj.resultset)
	local status = assert(res.query_status)

	assert(proxy.MYSQLD_PACKET_OK == 0, "OK != 0")
	assert(proxy.MYSQLD_PACKET_ERR == 255, "ERR != 255")

	if status == proxy.MYSQLD_PACKET_OK then
		if inj.query == string.char(proxy.COM_QUERY) .. "INSERT INTO test.t1 VALUES ( 1 )" then
			-- convert a OK packet with affected rows into a resultset
			local affected_rows = assert(res.affected_rows)
			local insert_id     = assert(res.insert_id)

			proxy.response = {
				type = proxy.MYSQLD_PACKET_OK,
				resultset = {
					fields = { 
						{ name = "affected_rows",
						  type = proxy.MYSQL_TYPE_LONG },
						{ name = "insert_id",
						  type = proxy.MYSQL_TYPE_LONG },
					},
					rows = {
						{ affected_rows, insert_id }
					}
				}
			}
			return proxy.PROXY_SEND_RESULT
		elseif inj.query == string.char(proxy.COM_QUERY) .. "SELECT row_count(1), bytes()" then
			-- convert a OK packet with affected rows into a resultset
			assert(res.affected_rows == nil)
			proxy.response = {
				type = proxy.MYSQLD_PACKET_OK,
				resultset = {
					fields = { 
						{ name = "row_count",
						  type = proxy.MYSQL_TYPE_LONG },
						{ name = "bytes",
						  type = proxy.MYSQL_TYPE_LONG },
					},
					rows = {
						{ res.row_count, res.bytes }
					}
				}
			}
			return proxy.PROXY_SEND_RESULT
		elseif inj.query == string.char(proxy.COM_QUERY) .. "SELECT 5.0" then
			-- test if we decode a 5.0 resultset nicely
			assert(res.affected_rows == nil)
			proxy.response = {
				type = proxy.MYSQLD_PACKET_OK,
				resultset = {
					fields = { 
						{ name = "row_count",
						  type = proxy.MYSQL_TYPE_LONG },
						{ name = "bytes",
						  type = proxy.MYSQL_TYPE_LONG },
					},
					rows = {
						{ res.row_count, res.bytes }
					}
				}
			}
			return proxy.PROXY_SEND_RESULT
		elseif inj.query == string.char(proxy.COM_QUERY) .. "SELECT 4.1" then
			-- test if we decode a 4.1 resultset too (shorter EOF packets)
			assert(res.affected_rows == nil)
			proxy.response = {
				type = proxy.MYSQLD_PACKET_OK,
				resultset = {
					fields = { 
						{ name = "row_count",
						  type = proxy.MYSQL_TYPE_LONG },
						{ name = "bytes",
						  type = proxy.MYSQL_TYPE_LONG },
					},
					rows = {
						{ res.row_count, res.bytes }
					}
				}
			}
			return proxy.PROXY_SEND_RESULT
		end
	elseif status == proxy.MYSQLD_PACKET_ERR then
		if inj.query == string.char(proxy.COM_QUERY) .. "SELECT error_msg()" then
			-- convert a OK packet with affected rows into a resultset
			assert(res.raw)
			local err = proto.from_err_packet(res.raw)

			proxy.response = {
				type = proxy.MYSQLD_PACKET_OK,
				resultset = {
					fields = { 
						{ name = "errcode",
						  type = proxy.MYSQL_TYPE_STRING },
						{ name = "errmsg",
						  type = proxy.MYSQL_TYPE_STRING },
						{ name = "sqlstate",
						  type = proxy.MYSQL_TYPE_STRING },
					},
					rows = {
						{ err.errcode, err.errmsg, err.sqlstate }
					}
				}
			}
			return proxy.PROXY_SEND_RESULT
		end

	else
		assert(false, ("res.query_status is %d, expected %d or %d"):format(
			res.query_status,
			proxy.MYSQLD_PACKET_OK,
			proxy.MYSQLD_PACKET_ERR
		))
	end
end

