-- Rate-limit public Member registration before service-role account creation.
-- Does not alter the Owner's existing email verification or login controls.
CREATE OR REPLACE FUNCTION public.ci_member_registration_rate_check(
  p_key_hash text,
  p_action text,
  p_max_attempts integer,
  p_window_seconds integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_attempts integer;
BEGIN
  IF p_key_hash !~ '^[a-f0-9]{64}$'
      OR p_action NOT IN ('member_register_email', 'member_register_ip')
      OR p_max_attempts < 1 OR p_max_attempts > 30
      OR p_window_seconds < 60 OR p_window_seconds > 86400 THEN
    RAISE EXCEPTION 'Invalid member registration rate parameters'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.ci_auth_rate_limits AS existing
    (key_hash, action, window_start, attempts)
  VALUES (p_key_hash, p_action, now(), 1)
  ON CONFLICT (key_hash, action)
  DO UPDATE SET
    attempts = CASE
      WHEN existing.window_start <= now() - make_interval(secs => p_window_seconds)
        THEN 1 ELSE existing.attempts + 1 END,
    window_start = CASE
      WHEN existing.window_start <= now() - make_interval(secs => p_window_seconds)
        THEN now() ELSE existing.window_start END
  RETURNING attempts INTO current_attempts;

  RETURN current_attempts <= p_max_attempts;
END;
$$;

REVOKE ALL ON FUNCTION public.ci_member_registration_rate_check(text,text,integer,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ci_member_registration_rate_check(text,text,integer,integer) FROM anon;
REVOKE ALL ON FUNCTION public.ci_member_registration_rate_check(text,text,integer,integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.ci_member_registration_rate_check(text,text,integer,integer) TO service_role;
