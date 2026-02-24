CREATE OR REPLACE FUNCTION public.handle_user_email_update()
RETURNS trigger AS $$
BEGIN
  -- Using WARNING so Supabase doesn't filter it out of the Postgres Logs
  RAISE WARNING '⚡ [EMAIL_TEST] Trigger fired for ID: %', NEW.id;
  RAISE WARNING '⚡ [EMAIL_TEST] OLD email: % | NEW email: %', OLD.email, NEW.email;
  RAISE WARNING '⚡ [EMAIL_TEST] OLD change: % | NEW change: %', OLD.email_change, NEW.email_change;

  IF (OLD.email IS DISTINCT FROM NEW.email) OR 
     (OLD.email_change IS DISTINCT FROM NEW.email_change AND (NEW.email_change IS NULL OR NEW.email_change = '')) THEN
    
    RAISE WARNING '✅ [EMAIL_TEST] Condition met! Updating public.profiles...';
    
    UPDATE public.profiles
    SET
      email_verified = true,
      email = NEW.email
    WHERE id = NEW.id;

  ELSE
    RAISE WARNING '❌ [EMAIL_TEST] No email change detected in this specific update.';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_email_update ON auth.users;

CREATE TRIGGER on_auth_user_email_update
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_email_update();