from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('accounts', '0003_user_birth_date_user_phone')]
    operations = [
        migrations.AddField(model_name='user', name='reset_digest', field=models.CharField(max_length=64, blank=True)),
        migrations.AddField(model_name='user', name='reset_expires_at', field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name='user', name='reset_sent_at', field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name='user', name='reset_attempts', field=models.PositiveSmallIntegerField(default=0)),
    ]
