-- REFACTORING SUMMARY
-- JojoKit Combat System - Structure & Naming Improvements

--[[
  KEY IMPROVEMENTS:

  1. NAMING CONVENTIONS (improved clarity):
     - StateService → StateManager (clearer purpose as manager, not service)
     - guard() → canExecute() (more descriptive)
     - HitboxController → hitboxController (camelCase for local instances)
     - AnimationQueue → animationQueue (consistency)
     - dispatchCount → dispatchCounts (plural for map)
     - t → actionTemplate (clarity over brevity)
     - payload.Character → targeting (implicit from context)
     - BINDINGS → INPUT_BINDINGS (explicit scope)
     - Equip.luau → StandEquip.luau (explicit action name)
     - show/hide (functions) → showStand/hideStand (explicit)

  2. STRUCTURE IMPROVEMENTS:

     a) StateManager (Server):
        - Separated concerns: disconnect(), reset(), setup() functions
        - Explicit named connection fields: characterAdded, humanoidDied
        - Clearer lifecycle hooks for character/death
        - Better nil-safety with type hints

     b) ReplicationService (Server):
        - Added validateDispatch() helper function
        - Better error messages with semantic reasons
        - Clearer variable naming: resultState, validErr
        - Improved logging throughout

     c) ReplicationController (Client):
        - Separated handleReconcile() and handleBroadcast() functions
        - Clear MAX_PENDING_ACTIONS guard to prevent queue overflow
        - Better organization of signal connections
        - Explicit Predict/Dispatch separation

     d) Punch.luau:
        - ACTION_NAME constant for consistency
        - Clear predict/reset functions with explicit purposes
        - Better logging with semantic tags
        - Renamed all camelCase locals consistently

     e) Hit.luau:
        - pointInBox() helper for clarity
        - safeGetHumanoidRoot() with proper type narrowing
        - Semantic validation errors
        - Better dummy/player target resolution

     f) InputController:
        - INPUT_BINDINGS with canExecute guard
        - Simpler binding loop using ipairs
        - Clearer action dispatch

     g) StandVisual:
        - showStand/hideStand explicit functions
        - attachmentTokens for predictability
        - Better cleanup with nil checks
        - Clearer attachment state tracking

  3. NEW SYSTEMS:

     a) StatusManager (Shared):
        - Predictive status effect system
        - Registration pattern for extensibility
        - Apply/Remove/Query status effects
        - Automatic expiration on server
        - Supports both players and models
        
        Example usage:
          StatusManager.registerStatus({
            name = "Stunned",
            duration = 2.0,
            onApply = function(target, data)
              -- Visual feedback
            end,
            onRemove = function(target, data)
              -- Cleanup
            end
          })
          
          StatusManager.applyStatus(player, "Stunned", { severity = 1 })
          if StatusManager.hasStatus(player, "Stunned") then
            -- Player is stunned
          end

  4. TYPE SAFETY IMPROVEMENTS:
     - Fixed Union type errors in Registry (ServerHandler | ClientHandler)
     - Added proper BasePart type narrowing in Hit.luau
     - Explicit optional connection fields in StateManager
     - All function signatures properly annotated

  5. MEMORY & CONNECTION SAFETY:
     - Weak keys in AnimationController prevents entity leaks
     - userId-keyed registries avoid Player reference retention
     - Proper cleanup on PlayerRemoving
     - Explicit disconnection of named connections
     - Token invalidation prevents race conditions

  6. SCALABILITY PATTERNS:
     - StatusManager enables easy addition of buff/debuff systems
     - ReplicationRegistry supports both server/client handlers via union
     - Action handlers follow consistent template pattern
     - State changes centralized via State.listen/State.setBatch
     - Predictive system allows client-side optimization without cheating

--]]

return {
	Version = "1.0",
	LastUpdated = "2024",
	Patterns = {
		"Predictive Client with Server Reconciliation",
		"Centralized State Management",
		"Type-Safe Action Registry",
		"Predictive Status Effects",
		"Memory-Leak Prevention",
	},
}
