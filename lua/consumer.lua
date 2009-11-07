
--[[
   Author: Julio Manuel Fernandez-Diaz
   Date:   January 12, 2007
   (For Lua 5.1)
   
   Modified slightly by RiciLake to avoid the unnecessary table traversal in tablecount()

   Formats tables with cycles recursively to any depth.
   The output is returned as a string.
   References to other tables are shown as values.
   Self references are indicated.

   The string returned is "Lua code", which can be procesed
   (in the case in which indent is composed by spaces or "--").
   Userdata and function keys and values are shown as strings,
   which logically are exactly not equivalent to the original code.

   This routine can serve for pretty formating tables with
   proper indentations, apart from printing them:

      print(table.show(t, "t"))   -- a typical use
   
   Heavily based on "Saving tables with cycles", PIL2, p. 113.

   Arguments:
      t is the table.
      name is the name of the table (optional)
      indent is a first indentation (optional).
--]]
function table.show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else 
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] 
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end







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
local luamysql = assert(require("luasql.mysql"))
local db = assert(luamysql.mysql());

-- TODO: make this read from a config file
conn = assert(db:connect("flexviews", "root", "flexroot", "127.0.0.1", 3307))
conn:setautocommit(true)

-- retrieve a cursor
cur = assert (conn:execute"SHOW BINARY LOGS;")
-- print all rows, the rows will be indexed by field names
row = cur:fetch ({}, "n")
while row do
  -- print(table.show(row))
  --  print(string.format("Name: %s", row.log_name))
  -- reusing the table of results
  
  print(string.format("INSERT INTO flexviews.binlog_consumer_status (master_log_file, master_log_size, exec_master_pos) values ('%s', %d, 0) ON DUPLICATE KEY UPDATE master_log_size = %d ;", row[1], row[2], row[2]))
  row = cur:fetch (row, "n")
end
-- close the cursor
cur:close()



-- retrieve a cursor
cur = assert (conn:execute"SELECT bcs.*, setting_value from flexviews.binlog_consumer_status bcs join flexviews.mview_settings where setting_key ='log_bin' and exec_master_pos < master_log_size order by master_log_file;")
-- print all rows, the rows will be indexed by field names
row = cur:fetch ({}, "n")
while row do
  print(string.format("PROCESS BINARY LOG: %s%s, size:%d, exec_at:%d, exec_to:%d", row[4], row[1], row[2], row[3], row[2]))
  row = cur:fetch (row, "n")
end
-- close the cursor
cur:close()
conn:close()
db:close()


function process_binlog(logfile) 
 -- local logfile = "/tmp/rbr.bin"
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


end -- FUNCTION



-- [PROGRAM ENDS HERE]


