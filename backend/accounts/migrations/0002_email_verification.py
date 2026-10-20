from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('accounts', '0001_initial')]
    operations = [
        migrations.AddField(model_name='user', name='email_verified', field=models.BooleanField(default=False)),
        migrations.AddField(model_name='user', name='verification_digest', field=models.CharField(max_length=64, blank=True)),
        migrations.AddField(model_name='user', name='verification_expires_at', field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name='user', name='verification_sent_at', field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name='user', name='verification_attempts', field=models.PositiveSmallIntegerField(default=0)),
    ]
