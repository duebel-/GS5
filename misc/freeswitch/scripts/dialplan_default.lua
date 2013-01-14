-- Gemeinschaft 5 default dialplan
-- (c) AMOOMA GmbH 2012
-- 


function hangup_hook_caller(s, status, arg)
  log:info('HANGUP_HOOK: ', status)
  if tostring(status) == 'transfer' then
    if start_caller and start_caller.destination then
      log:info('CALL_TRANSFERRED - destination was: ', start_caller.destination.type, '=', start_caller.destination.id,', number: ' .. tostring(start_caller.destination.number) .. ', to: ' .. start_caller:to_s('sip_refer_to'));
      start_caller.auth_account            = start_dialplan:object_find(start_caller.destination.type, start_caller.destination.id);
      start_caller.forwarding_number       = start_caller.destination.number;
      start_caller.forwarding_service      = 'transfer';
    end
  end
end

-- initialize logging
require 'common.log'
log = common.log.Log:new{ prefix = '### [' .. session:get_uuid() .. '] ' };

-- caller session object
require 'dialplan.session'
start_caller = dialplan.session.Session:new{ log = log, session = session };

-- connect to database
require 'common.database'
local database = common.database.Database:new{ log = log }:connect();
if not database:connected() then
  log:critical('DIALPLAN_DEFAULT - database connect failed');
  return;
end

-- dialplan object
require 'dialplan.dialplan'

start_dialplan = dialplan.dialplan.Dialplan:new{ log = log, caller = start_caller, database = database };
start_dialplan:configuration_read();
start_caller.local_node_id = start_dialplan.node_id;
start_caller:init_channel_variables();

-- session:execute('info','notice');

if not start_dialplan:check_auth() then
  log:debug('AUTHENTICATION_REQUIRED - host: ' , start_caller.sip_contact_host, ', domain: ', start_dialplan.domain);
  start_dialplan:hangup(407, start_dialplan.domain);
  return false;
end

if start_caller.from_node and not start_dialplan:check_auth_node() then
  log:debug('AUTHENTICATION_REQUIRED_NODE - node_id: ', start_caller.node_id, ', domain: ', start_dialplan.domain);
  start_dialplan:hangup(407, start_dialplan.domain);
else
  start_destination = { type = 'unknown' }
  start_caller.session:setHangupHook('hangup_hook_caller', 'destination_number');
  start_dialplan:run(start_destination);
end

-- release database handle
if database then
  database:release();
end
