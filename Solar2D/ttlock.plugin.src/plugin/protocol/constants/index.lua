--------------------------------------------------------------------------------
-- index.lua - TTLock Constants Module Index
--------------------------------------------------------------------------------

local Constants = {
    CyclicOpType          = require("plugin.protocol.constants.CyclicOpType"),
    DateConstant          = require("plugin.protocol.constants.DateConstant"),
    DeviceInfoEnum        = require("plugin.protocol.constants.DeviceInfoEnum"),
    FeatureValue          = require("plugin.protocol.constants.FeatureValue"),
    ICOperate             = require("plugin.protocol.constants.ICOperate"),
    KeyboardPwdType       = require("plugin.protocol.constants.KeyboardPwdType"),
    LockType              = require("plugin.protocol.constants.LockType"),
    LockedStatus          = require("plugin.protocol.constants.LockedStatus"),
    LogOperate            = require("plugin.protocol.constants.LogOperate"),
    LogOperateCategory    = require("plugin.protocol.constants.LogOperateCategory"),
    LogOperateNames       = require("plugin.protocol.constants.LogOperateNames"),
    LogType               = require("plugin.protocol.constants.LogType"),
    OperationType         = require("plugin.protocol.constants.OperationType"),
    PassageModeOperate    = require("plugin.protocol.constants.PassageModeOperate"),
    PassageModeType       = require("plugin.protocol.constants.PassageModeType"),
    PwdOperateType        = require("plugin.protocol.constants.PwdOperateType"),
    
    -- Newly added constants
    ActionType            = require("plugin.protocol.constants.ActionType"),
    APICommand            = require("plugin.protocol.constants.APICommand"),
    AudioManage           = require("plugin.protocol.constants.AudioManage"),
    AutoLockOperate       = require("plugin.protocol.constants.AutoLockOperate"),
    CallbackOperationType = require("plugin.protocol.constants.CallbackOperationType"),
    CommandResponse       = require("plugin.protocol.constants.CommandResponse"),
    CommandType           = require("plugin.protocol.constants.CommandType"),
    ConfigRemoteUnlock    = require("plugin.protocol.constants.ConfigRemoteUnlock"),
}

return Constants