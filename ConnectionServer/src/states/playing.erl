-module(playing).

-include("protocol.hrl").
-include("state.hrl").
-include("charinfo.hrl").
-include("vec.hrl").

% States
-export([
    event/2
    ]).

event(tcp_closed, State) ->
    CharInfo = State#state.charinfo,
    % For now we logout the player if the connection is lost. Should
    % be changed to persist in case of reconnect.
	%CharInfo#charinfo.pid ! {execute, {from, self()}, {call, logout}, 
    %    {args, []}},
    %Pid = CharInfo#charinfo.pid, 
    %rpc:call(node(Pid), obj, async_call, [Pid, logout]),
    Pid = CharInfo#charinfo.pid,
	rpc:call(node(Pid), obj, async_call, [Pid, logout]), 
    {noreply, playing, State};

event({terrain, Terrain}, State) ->
    %error_logger:info_report([{sending, ?TERRAIN, Terrain}]),
    TerrainBin = list_to_binary(Terrain),
    Len = byte_size(TerrainBin),
    {reply, <<?TERRAIN, Len, TerrainBin/binary>>, playing, State};

event({skybox, SkyBox}, State) ->
	SkyBoxStr = make_str(SkyBox),
    %SkyBoxBin = list_to_binary(SkyBox),
    %Len = byte_size(SkyBoxBin),
    %Reply = <<?SKYBOX, Len, SkyBoxBin/binary>>,
    %error_logger:info_report([{sending, ?SKYBOX, SkyBox, 
    %    byte_size(Reply)}]),
    {reply, <<?SKYBOX, SkyBoxStr/binary>>, playing, State};

event({new_pos, [Id, #vec{x=X, y=Y, z=Z}]}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?NEW_POS, IdStr/binary, X/little-float, Y/little-float,
				Z/little-float>>, playing, NewState}
	end;

event({msg, Msg}, State) ->
    %error_logger:info_report([{sending, ?MSG, Msg}]),
    MsgBin = list_to_binary(Msg),
    Len = byte_size(MsgBin),
    {reply, <<?MSG, Len, MsgBin/binary>>, playing, State};

event({mesh, [Id, Mesh]}, State) ->
    IdLen = byte_size(Id),
    MeshBin = list_to_binary(Mesh),
    MeshLen = byte_size(MeshBin),
    %error_logger:info_report([{connsrv, playing, mesh, ?MESH, IdLen, Id, 
    %    MeshLen, MeshBin}]),
    {reply, <<?MESH, IdLen:8/little-integer, Id/binary, 
        MeshLen:8/little-integer, MeshBin/binary>>, playing, State};

event({billboard, [Id, Billboard]}, State) ->
    IdLen = byte_size(Id),
    BillboardBin = list_to_binary(Billboard),
    BillboardLen = byte_size(BillboardBin),
    %error_logger:info_report([{billboard, ?BILLBOARD, IdLen, Id, 
    %    BillboardLen, BillboardBin}]),
    {reply, <<?BILLBOARD, IdLen, Id/binary, BillboardLen, 
        BillboardBin/binary>>, playing, State};

%event({scale, [Id, Scale]}, State) ->
%    IdLen = byte_size(Id),
%    %error_logger:info_report([{scale, ?SCALE, IdLen, Id, Scale}]),
%    {reply, <<?SCALE, IdLen, Id/binary, Scale/little-float>>, playing, 
%        State};

event({ambient_light, Value}, State) ->
    {reply, <<?AMBIENT_LIGHT, Value/little-float>>, playing, 
        State};

event({obj_pos, {id, Id}, {pos, #vec{x=X, y=Y, z=Z}}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		%error_logger:info_report([{obj_pos, ?OBJ_POS, IdStr, X, Y, Z}]),
   			 {reply, <<?OBJ_POS, IdStr/binary, X/little-float,
      	 		 Y/little-float, Z/little-float>>, playing, NewState}
	end;

event({obj_dir, {id, Id}, {dir, #vec{x=X, y=Y, z=Z}}}, State) ->
	TimeStamp = <<"FakeTimeStamp">>,
	event({obj_dir, 
		{id, Id},
		{dir, #vec{x=X, y=Y, z=Z}},
		{timestamp, TimeStamp}}, State);
	

event({obj_dir, {id, Id}, {dir, #vec{x=X, y=Y, z=Z}}, 
		{timestamp, TimeStamp}}, State) ->
    %error_logger:info_report([{obj_dir, ?OBJ_DIR, Id, Id, X, Y, Z}]),
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_DIR, IdStr/binary,
				X/little-float, Y/little-float, Z/little-float,
				TimeStamp/binary>>, playing, NewState}
	end;



event({obj_shot, {id, Id}, {shot_pos, #vec{x=X, y=Y, z=Z}}},  State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_SHOT, IdStr/binary, X/little-float,
       		 Y/little-float, Z/little-float>>, playing, NewState}
	end;

event({obj_created, {id, Id}}, State) ->
    IdLen = byte_size(Id),
    %error_logger:info_report([{obj_created, Id}]),
    {reply, <<?OBJ_CREATED, IdLen, Id/binary>>, 
        playing, State};

event({obj_leave, {id, Id}}, State) ->
	IdStr = make_str(Id),
    {reply, <<?OBJ_LEAVE, IdStr/binary>>, playing, State};

event({obj_enter, {id, Id}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_ENTER, IdStr/binary>>, playing, NewState}
	end;

event({obj_anim, {id, Id}, {animstr, AnimBin}}, State) ->
    AnimStr = make_str(AnimBin),
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_ANIM, IdStr/binary, AnimStr/binary>>,
       			 playing, NewState}
	end;

event({obj_dead, {id, Id}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_DEAD, IdStr/binary>>, playing, NewState}
	end;



event({obj_logout, {id, Id}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_LOGOUT, IdStr/binary>>, playing, NewState}
	end;

event({obj_vector, {id, Id}, {velocity, Velocity}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_VECTOR, IdStr/binary, Velocity:8/integer>>, playing, NewState}
	end;


event({obj_jump, {id, Id}, {force, #vec{x=X, y=Y, z=Z}}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_JUMP, IdStr/binary, X/little-float,
        		Y/little-float, Z/little-float>>, playing, NewState}
	end;

event({obj_faction, {id, Id}, {faction, red}}, State) ->
    FactionStr  = make_str(<<"Red">>),
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_FACTION, IdStr/binary, FactionStr/binary>>, 
				playing, NewState}
	end;

event({obj_faction, {id, Id}, {faction, blue}}, State) ->
    FactionStr  = make_str(<<"Blue">>),
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_FACTION, IdStr/binary, FactionStr/binary>>, 
				playing, NewState}
	end;


event({obj_respawn, {id, Id}, {pos, #vec{x=X, y=Y, z=Z}}}, State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_RESPAWN, IdStr/binary, 
				X/little-float, Y/little-float, Z/little-float>>, 
				playing, NewState}
	end;

event({obj_jump_slam_attack, {id, Id}, {str, Str}, {vec, #vec{x=X, y=Y, z=Z}}}, 
		State) ->
	IdStr = make_str(Id),
	StrBin = make_str(Str),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?OBJ_JUMP_SLAM_ATTACK, IdStr/binary, StrBin/binary,
				X/little-float, Y/little-float, Z/little-float>>, 
				playing, NewState}
	end;

event({entity_interpolation, {id, Id},
		{pos, #vec{x=PosX, y=PosY, z=PosZ}}, 
		{dir, #vec{x=DirX, y=DirY, z=DirZ}}, 
		{vel, #vec{x=VelX, y=VelY, z=VelZ}}}, 
		State) ->
	IdStr = make_str(Id),
	case validate_id(IdStr, State) of
		{false, NewState} ->
    		{noreply, playing, NewState};
		{true, NewState} ->
    		{reply, <<?ENTITY_INTERPOLATION, IdStr/binary,
				PosX/little-float, PosY/little-float, PosZ/little-float, 
				DirX/little-float, DirY/little-float, DirZ/little-float, 
				VelX/little-float, VelY/little-float, VelZ/little-float>>, 
				playing, NewState}
	end;

event({pong, Time}, State) ->
    {reply, <<?NOTIFY_PONG, Time/binary>>, playing, State};

event({test_state_update, Timestamp}, State) ->
    {reply, <<?TEST_STATE_UPDATE, Timestamp/binary>>, playing, State};

event(<<?QUERY_ENTITY, _IdLen:8/integer, Id/binary>>, State) ->
    CharInfo = State#state.charinfo,
    obj_call(CharInfo#charinfo.pid, pulse, [Id]),
    {noreply, playing, State};

event(<<?PULSE>>, #state{charinfo=CharInfo} = State) ->
    obj_call(CharInfo#charinfo.pid, pulse),
    {noreply, playing, State};

event(<<?SYNC_POS, 
		X/little-float, Y/little-float, Z/little-float,
		DirX/little-float, DirY/little-float, DirZ/little-float, 
		VelX/little-float, VelY/little-float, VelZ/little-float>>, 
    	State) ->
    CharInfo = State#state.charinfo,
    obj_call(CharInfo#charinfo.pid, sync_pos, [
		#vec{x=X, y=Y, z=Z},
		#vec{x=DirX, y=DirY, z=DirZ},
		#vec{x=VelX, y=VelY, z=VelZ}
		]),
    {noreply, playing, State};

event(<<?INCREASE_SPEED, TimeStamp/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
	rpc:call(node(Pid), obj, async_call, [Pid, increase_speed, 
        [TimeStamp]]),
    {noreply, playing, State};

event(<<?DECREASE_SPEED, TimeStamp/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
	rpc:call(node(Pid), obj, async_call, [Pid, decrease_speed, 
        [TimeStamp]]),
    {noreply, playing, State};

event(<<?SET_DIR, X/little-float, Y/little-float, Z/little-float,
    TimeStamp/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
	rpc:call(node(Pid), obj, async_call, [Pid, set_dir, 
        [#vec{x=X, y=Y, z=Z}, TimeStamp]]),
    {noreply, playing, State};

event(<<?SET_VECTOR, Velocity:8/integer, _TimeStamp/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
	rpc:call(node(Pid), obj, async_call, [Pid, set_vector, [Velocity]]),
    {noreply, playing, State};

event(<<?JUMP, X/little-float, Y/little-float, Z/little-float,
		_TimeStamp/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
	rpc:call(node(Pid), obj, async_call, [Pid, jump, 
        [#vec{x=X, y=Y, z=Z}]]),
    {noreply, playing, State};

%event(<<?SET_NAME, NameLen:8/integer, Name:NameLen/binary>>, State) ->
%    CharInfo = State#state.charinfo,
%    Pid = CharInfo#charinfo.pid,
%    error_logger:info_report([{set_name, Name}]),
%	rpc:call(node(Pid), obj, async_call, [Pid, set_name, [Name]]),
%    {noreply, playing, State};

%event(<<?GET_NAME, IdLen:8/integer, Id:IdLen/binary>>, State) ->
%    CharInfo = State#state.charinfo,
%    Pid = CharInfo#charinfo.pid,
%	rpc:call(node(Pid), obj, async_call, [Pid, get_name, [Id]]),
%    {noreply, playing, State};

%event(<<?SAVE>>, State) ->
%    CharInfo = State#state.charinfo,
%    Pid = CharInfo#charinfo.pid,
%	rpc:call(node(Pid), obj, async_call, [Pid, save, 
%        [State#state.account]]),
%    {noreply, playing, State};

%event(<<?ENABLE_FLYING>>, State) ->
%    CharInfo = State#state.charinfo,
%    Pid = CharInfo#charinfo.pid,
%	rpc:call(node(Pid), obj, async_call, [Pid, enable_flying]),
%    {noreply, playing, State};

%event(<<?DISABLE_FLYING>>, State) ->
%    CharInfo = State#state.charinfo,
%    Pid = CharInfo#charinfo.pid,
%	rpc:call(node(Pid), obj, async_call, [Pid, disable_flying]),
%    {noreply, playing, State};

event(<<?PING, Time/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
    obj_call(Pid, ping, [Time]),
    {noreply, playing, State};

event(<<?SET_SHOT, IdLen:8/integer, Id:IdLen/binary,
		X/little-float, Y/little-float, Z/little-float>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
    obj_call(Pid, set_shot, [Id, #vec{x=X, y=Y, z=Z}]),
    {noreply, playing, State};

event(<<?SET_ANIM, StrLen:8/integer, Str:StrLen/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
    obj_call(Pid, set_anim, [Str]),
    {noreply, playing, State};

event(<<?SET_RESPAWN>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
    obj_call(Pid, set_respawn),
    {noreply, playing, State};

event(<<?SET_JUMP_SLAM_ATTACK, StrLen:8/integer, Str:StrLen/binary,
		X/little-float, Y/little-float, Z/little-float>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
	Vec = #vec{x=X, y=Y, z=Z},
    obj_call(Pid, set_jump_slam_attack, [Str, Vec]),
    {noreply, playing, State};

event(<<?TEST_STATE_UPDATE, 
        KeyLen:8/integer, Key:KeyLen/binary,
        ValLen:8/integer, Val:KeyLen/binary,
        Timestamp/binary>>, State) ->
    CharInfo = State#state.charinfo,
    Pid = CharInfo#charinfo.pid,
    obj_call(Pid, test_state_update, [Key, Val]),
    {noreply, playing, State};

event(Event, State) ->
    error_logger:info_report([{unknown_event, Event}]),
    {noreply, playing, State}.

obj_call(Pid, Fun) ->
    rpc:call(node(Pid), obj, async_call, [Pid, Fun]).

obj_call(Pid, Fun, Args) ->
    rpc:call(node(Pid), obj, async_call, [Pid, Fun, Args]).

make_str(Bin) ->
	BinLen = byte_size(Bin),
	<<BinLen:8, Bin/binary>>.		

validate_id(<<Bin/binary>>, #state{validate_id_regexp=undefined} = State) ->
	{ok, RegExp} = re:compile("^[a-zA-Z0-9-_]+@[a-zA-Z0-9_-]+#[0-9]+"),
	validate_id(Bin, State#state{validate_id_regexp=RegExp});

validate_id(<<_IdLen:8, Id/binary>>, #state{validate_id_regexp=RegExp} = State) ->
	case re:run(Id, RegExp) of
		nomatch ->
			error_logger:info_report({invalid_id, Id}),
			{false, State};
		{match, _} ->
			{true, State}
	end.
