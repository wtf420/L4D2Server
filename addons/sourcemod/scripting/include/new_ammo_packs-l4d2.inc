#if defined _naphelpers_included_
  #endinput
#endif
#define _naphelpers_included_

enum L4D2UseAction
{
    L4D2UseAction_None              = 0, // No use action active
    L4D2UseAction_Healing           = 1, // Includes healing yourself or a teammate.
    L4D2UseAction_Defibing          = 4, // When defib'ing a dead body.
    L4D2UseAction_GettingDefibed    = 5, // When comming back to life from a dead body.
    L4D2UseAction_PouringGas        = 8, // Pouring gas into a generator
    L4D2UseAction_Cola              = 9, // For Dead Center map 2 cola event, when handing over the cola to whitalker.
    L4D2UseAction_Button            = 10 // Such as buttons, timed buttons, generators, etc.
    /* List is not fully done, these are just the ones I have found so far */
}

enum L4D2GlowType
{
    L4D2Glow_None                   = 0,
    L4D2Glow_OnUse                  = 1,
    L4D2Glow_OnLookAt               = 2,
    L4D2Glow_Constant               = 3
}

/**
 * Fires when the plugin is (un)loaded.
 *
 * @param iState		Initialization state.
 * @noreturn
 */
forward void NAP_OnInit(int iState);

/**
 * Fires before a Heal Box's effect is applied to the deployer.
 * @remarks This forward only runs when nap-l4d2_heal_type is
 *          set to 3.
 *
 * @param client		Given client index
 * @noreturn
 */
forward void NAP_OnHBPre(int client);

/**
 * Fires during the effect of a Heal Box being applied to the deployer.
 * @remarks This forward only runs when nap-l4d2_heal_type is set to 3.
 *
 * @param client		Given client index
 * @noreturn
 */
forward void NAP_OnHB(int client);

/**
 * Fires after a Heal Box's effect is applied to the deployer.
 * @remarks This forward only occurs when nap-l4d2_heal_type
 *          is set to 3.
 *
 * @param client		Given client index
 * @noreturn
 */
forward void NAP_OnHBPost(int client);

/**
 * Fires when an airstrike bomb explodes at a position.
 *
 * @param fHitX		X axis of the bombed position
 * @param fHitY		Y axis of the bombed position
 * @param fHitZ		Z axis of the bombed position
 *
 * @noreturn
 */
forward void NAP_OnAirstikeHit(float fHitX, float fHitY, float fHitZ);

/**
 * Checks to see if a client still feels effects from deployed ammo packs.
 *
 * @param client		Client index
 * @param effectIndex	Index of ammo pack with effect.
 *
 * @error				Invalid client or incorrect index
 * @return				true if it is still there, false otherwise
 */
native bool HasEffect(int client, int effectIndex);

/**
 * Returns the time left an ammo pack effect has.
 *
 * @param client		Client index
 * @param effectIndex	Index of ammo pack with effect
 *
 * @error				Invalid client or incorrect index
 * @return				time left on success, 0.0 on failure
 */
native float GetEffectTime(int client, int effectIndex);

/**
 * Gets the index of a deployer's ammo pack.
 *
 * @param client		Client index
 * @param effectIndex	Index of ammo pack with effect
 *
 * @error				Invalid client
 * @return				deployer's ammo pack index, else 0
 */
native int GetAPIndex(int client);

/**
 * Sets the index of a deployer's ammo pack.
 *
 * @param client		Client index
 * @param APIndex		Chosen index of ammo pack.
 *
 * @error				Invalid client or incorrect index
 * @noreturn
 */
native void SetAPIndex(int client, int APIndex);

/**
 * Gets the name of the ammo pack being deployed.
 *
 * @param client		Client index
 * @param sBuffer		String used to store the name
 * @param iBufferSize	Size of the string
 *
 * @error				Invalid client or incorrect buffer size
 * @return				Number of bytes written
 */
native int GetAPName(int client, char[] sBuffer, int iBufferSize);

/**
 * Sets the name of the ammo pack being deployed.
 *
 * @param client		Client index
 * @param sBuffer		String used to change the name
 *
 * @error				Invalid client
 * @noreturn
 */
native void SetAPName(int client, char[] sBuffer);

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @param range            Glow max range, 0 for unlimited.
 * @param minRange        Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing        Whether the glow will be flashing.
 * @return                True if glow was set, false if entity does not support
 *                        glow.
 */
stock bool L4D2_SetEntGlow(int entity, L4D2GlowType type, int range, int minRange, int colorOverride[3], bool flashing)
{
    char netclass[128];
    GetEntityNetClass(entity, netclass, 128);

    int offset = FindSendPropInfo(netclass, "m_iGlowType");
    if (offset < 1)
    {
        return false;    
    }

    L4D2_SetEntGlow_Type(entity, type);
    L4D2_SetEntGlow_Range(entity, range);
    L4D2_SetEntGlow_MinRange(entity, minRange);
    L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
    L4D2_SetEntGlow_Flashing(entity, flashing);
    return true;
}

/**
 * Set entity glow type.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Type(int entity, L4D2GlowType type)
{
    SetEntProp(entity, Prop_Send, "m_iGlowType", view_as<int>(type));
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range            Glow range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Range(int entity, int range)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
}

/**
 * Set entity glow min range.
 *
 * @param entity        Entity index.
 * @parma minRange        Glow min range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_MinRange(int entity, int minRange)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity        Entity index.
 * @parma colorOverride    Glow color, RGB.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_ColorOverride(int entity, int colorOverride[3])
{
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity        Entity index.
 * @parma flashing        Whether glow will be flashing.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Flashing(int entity, bool flashing)
{
    SetEntProp(entity, Prop_Send, "m_bFlashing", view_as<int>(flashing));
}

/**
 * Returns player use action.
 *
 * @param client        Client index.
 * @return              Use action.
 * @error               Invalid client index.
 */
stock L4D2UseAction:L4D2_GetPlayerUseAction(client)
{
    return L4D2UseAction:GetEntProp(client, Prop_Send, "m_iCurrentUseAction");
}

/**
 * Returns player use action target.
 *
 * @param client        Client index.
 * @return              Entity index.
 * @error               Invalid client index.
 */
stock L4D2_GetPlayerUseActionTarget(client)
{
    return GetEntPropEnt(client, Prop_Send, "m_useActionTarget");
}

/**
 * Returns player use action owner.
 *
 * @param client        Client index.
 * @return              Entity index.
 * @error               Invalid client index.
 */
stock L4D2_GetPlayerUseActionOwner(client)
{
    return GetEntPropEnt(client, Prop_Send, "m_useActionOwner");
}

public void __pl_naphelpers_SetNTVOptional()
{
	MarkNativeAsOptional("HasEffect");
	MarkNativeAsOptional("GetEffectTime");
	MarkNativeAsOptional("GetAPIndex");
	MarkNativeAsOptional("SetAPIndex");
	MarkNativeAsOptional("GetAPName");
	MarkNativeAsOptional("SetAPName");
}

public SharedPlugin __pl_naphelpers =
{
	name = "nap-l4d2_helpers",
	file = "new_ammo_packs-l4d2.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

