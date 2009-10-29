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
local binlog = assert(require("mysql.binlog"))

local logfile = "/tmp/rbr.bin"
local f = assert(binlog.open(logfile))

for event in f:next() do
	assert(event.timestamp)
	assert(event.server_id)
	assert(event.type)
	assert(event.log_pos)
	assert(event.flags)
	assert(event.event_size)

	-- try to decode the event 
	if event.type == "QUERY_EVENT" then
		assert(event.query.thread_id)
		assert(event.query.exec_time)
		assert(event.query.error_code)
		assert(event.query.query)
		-- print(("%d: %s"):format(event.query.thread_id, event.query.query))

            	if event.query.query == "BEGIN" then
                	print(("COMMIT;\n--new unit of work\nBEGIN;\nSET SQL_LOG_BIN=1;\nINSERT INTO flexviews.mview_uow values(NULL,from_unixtime(%d));"):format(event.timestamp))
			print("-- start from here when replaying this transaction.")
                	print(("REPLACE INTO flexviews.binlog_consumer_status VALUES('%s',%d);"):
                      	format(logfile, event.log_pos))
			print("SET SQL_LOG_BIN=0;");
            	end
	
	elseif event.type == "ROTATE_EVENT" then
		assert(event.rotate.binlog_file)
		assert(event.rotate.binlog_pos)
		--
		-- file = event.rotate.binlog_file

	elseif event.type == "XID_EVENT" then
		assert(event.xid.xid_id)

	elseif event.type == "INTVAR_EVENT" then
		assert(event.intvar.type) -- that should be a string 
		assert(event.intvar.value)
	elseif event.type == "FORMAT_DESCRIPTION_EVENT" then
		assert(event.format.master_version)
		assert(event.format.binlog_version)
		assert(event.format.created_ts)
		-- print(("format: %d, %s, %d"):format(event.format.binlog_version, event.format.master_version, event.format.created_ts))
	elseif event.type == "TABLE_MAP_EVENT" then
		-- if we want RBR to work, we have to track the table-map events 
		--
		f:table_register(event.table_map) -- register the current table, can be table or event

		assert(event.table_map.table_id)
		assert(event.table_map.flags)
		assert(event.table_map.db_name)
		print(("use %s;"):format(event.table_map.db_name))
		assert(event.table_map.table_name)
		-- print(("tablemap: %d, %d, %s::%s"):format(event.table_map.table_id, event.table_map.flags, event.table_map.db_name, event.table_map.table_name))
	elseif event.type == "DELETE_ROWS_EVENT" or event.type == "UPDATE_ROWS_EVENT" or event.type == "WRITE_ROWS_EVENT" then
		local tbl = f:table_get(event.rbr.table_id)

		assert(event.rbr.table_id)
		assert(event.rbr.flags)

		print(("-- RBR: [%s] table=%d (%s), flags=%d"):format(event.type, event.rbr.table_id, tbl.table_name, event.rbr.flags))

		for row in event.rbr:next(tbl) do
			local before = row.before
			local after  = row.after

			if (before) then	
				local field_str = ""		
				for field_ndx, field in ipairs(before) do
					if field_str ~= "" then
						field_str = field_str .. ','
					end
					if tonumber(field) ~= nil then
						field_str = field_str .. field 
					else
						field_str = field_str .. "'" .. field .. "'"
					end
				end
				print(("INSERT INTO %s_mvlog VALUES(-1,@fv_uow_id,%s);"):format(tbl.table_name,field_str))
			end
			if (after) then
				local field_str = ""		
				for field_ndx, field in ipairs(after) do
					if field_str ~= "" then
						field_str = field_str .. ','
					end
					if tonumber(field) ~= nil then
						field_str = field_str .. field
					else
						field_str = field_str .. "'" .. field .. "'"
					end
				end
				print(("INSERT INTO %s_mvlog VALUES(1,@fv_uow_id,%s);"):format(tbl.table_name,field_str))
			end

		end
	else
		-- dump the unknown event to make it easier to add a decoder for them
		print(("-- unknown-event: %d, %d, %s"):format(event.timestamp, event.server_id, event.type))
	end

	---
	-- RBR 
	--
	-- track table-map definitions and decode RBR events
end

f:close()
