LinkLuaModifier("modifier_oaa_glaives_of_wisdom", "abilities/oaa_glaives_of_wisdom.lua", LUA_MODIFIER_MOTION_NONE)

silencer_glaives_of_wisdom_oaa = class(AbilityBaseClass)

function silencer_glaives_of_wisdom_oaa:GetIntrinsicModifierName()
  return "modifier_oaa_glaives_of_wisdom"
end

function silencer_glaives_of_wisdom_oaa:CastFilterResultTarget(target)
  local defaultResult = self.BaseClass.CastFilterResultTarget(self, target)
  local caster = self:GetCaster()
  if caster:HasScepter() and defaultResult == UF_FAIL_MAGIC_IMMUNE_ENEMY then
    return UF_SUCCESS
  else
    return defaultResult
  end
end

--------------------------------------------------------------------------------

modifier_oaa_glaives_of_wisdom = class(ModifierBaseClass)

function modifier_oaa_glaives_of_wisdom:IsHidden()
  return true
end

function modifier_oaa_glaives_of_wisdom:IsPurgable()
  return false
end

function modifier_oaa_glaives_of_wisdom:RemoveOnDeath()
  return false
end

function modifier_oaa_glaives_of_wisdom:OnCreated()
  if IsServer() then
    if not self.procRecords then
      self.procRecords = {}
    end
    self.parentOriginalProjectile = self:GetParent():GetRangedProjectileName()
    Debug.EnabledModules["abilities:oaa_glaives_of_wisdom"] = false
  end
end

modifier_oaa_glaives_of_wisdom.OnRefresh = modifier_oaa_glaives_of_wisdom.OnCreated

function modifier_oaa_glaives_of_wisdom:DeclareFunctions()
  return {
    MODIFIER_EVENT_ON_ATTACK,
    MODIFIER_EVENT_ON_ATTACK_LANDED,
    MODIFIER_EVENT_ON_ATTACK_FAIL,
    MODIFIER_EVENT_ON_ATTACK_START,
    MODIFIER_EVENT_ON_ATTACK_FINISHED
  }
end

function modifier_oaa_glaives_of_wisdom:OnAttackStart(keys)
  local parent = self:GetParent()
  local ability = self:GetAbility()
  -- Manual cast of attack modifier appears to make the damage_type 1115000
  -- May or may not work properly in practice
  if keys.attacker == parent and (keys.damage_type == 1115000 or ability:GetAutoCastState()) and ability:IsOwnersManaEnough() and keys.target.IsMagicImmune and (not keys.target:IsMagicImmune() or parent:HasScepter()) then
    -- Set projectile
    parent:SetRangedProjectileName("particles/units/heroes/hero_silencer/silencer_glaives_of_wisdom.vpcf")
  end
end

function modifier_oaa_glaives_of_wisdom:OnAttackFinished(keys)
  local parent = self:GetParent()
  if keys.attacker == parent then
    parent:SetRangedProjectileName(self.parentOriginalProjectile)
  end
end

function modifier_oaa_glaives_of_wisdom:OnAttack(keys)
  local parent = self:GetParent()
  local ability = self:GetAbility()
  -- Manual cast of attack modifier appears to make the damage_type 2
  -- May or may not work properly in practice
  if keys.attacker == parent and (keys.damage_type == 2 or ability:GetAutoCastState()) and ability:IsOwnersManaEnough() and keys.target.IsMagicImmune and (not keys.target:IsMagicImmune() or parent:HasScepter()) then
    -- Enable proc for this attack record number
    self.procRecords[keys.record] = true
    -- Using attack modifier abilities doesn't actually fire any cast events so we have to spend the mana here
    ability:PayManaCost()
  end
end

function modifier_oaa_glaives_of_wisdom:OnAttackLanded(keys)
  local parent = self:GetParent()
  if keys.attacker == parent and self.procRecords[keys.record] then
    local ability = self:GetAbility()
    local bonusDamagePct = ability:GetSpecialValueFor("intellect_damage_pct") / 100
    local player = parent:GetPlayerOwner()

    -- Check for +20% Glaive damage Talent
    if parent:HasLearnedAbility("special_bonus_unique_silencer_3") then
      bonusDamagePct = bonusDamagePct + parent:FindAbilityByName("special_bonus_unique_silencer_3"):GetSpecialValueFor("value") / 100
    end

    if parent:HasScepter() and keys.target:IsSilenced() then
      bonusDamagePct = bonusDamagePct * ability:GetSpecialValueFor("scepter_damage_multiplier")
    end

    local bonusDamage = parent:GetIntellect() * bonusDamagePct

    local damageTable = {
      victim = keys.target,
      attacker = parent,
      damage = bonusDamage,
      damage_type = ability:GetAbilityDamageType(),
      ability = ability
    }
    ApplyDamage(damageTable)
    SendOverheadEventMessage(player, OVERHEAD_ALERT_BONUS_SPELL_DAMAGE, keys.target, bonusDamage, player)
    keys.target:EmitSound("Hero_Silencer.GlaivesOfWisdom.Damage")
    self.procRecords[keys.record] = nil
  end
end

function modifier_oaa_glaives_of_wisdom:OnAttackFail(keys)
  local parent = self:GetParent()
  if keys.attacker == parent and self.procRecords[keys.record] then
    self.procRecords[keys.record] = nil
  end
end
