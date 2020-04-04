import pandas as pd
import numpy as np
from time import strftime
import datetime
import matplotlib.pyplot as plt
get_ipython().run_line_magic('matplotlib', 'inline')
import seaborn as sns

#выгрузка данных из таблицы
#Обратите внимание на slice [ : ], это чтобы не перегружаться 
df = pd.read_csv('ordersfull.csv', sep = ',', index_col = 0).head(500)

#Вычисляем и выводим в новый столбец дату регистрации водителя.
df['signup_date'] = df.groupby(by=['ID'], as_index = False)['date'].transform(lambda s: np.min(s.values))
df.signup_date = pd.to_datetime(df.signup_date, format='%Y-%m-%d')

#Вычисляем и выводим в новый столбец дату последней поездки водителя.
df.Today = datetime.date.today()
df.Today = pd.to_datetime(df.Today, format='%Y-%m-%d')
df.date = pd.to_datetime(df.date, format='%Y-%m-%d')
df['Last_day'] = df.groupby(by=['ID'], as_index=False)['date'].transform(lambda s: np.max(s.values))
df.Last_day = pd.to_datetime(df.Last_day, format='%Y-%m-%d')

#Вычисляем и выводим в новый столбец сколько дней прошло с регистрации водителя до заданной даты.
df['seniority'] = (df['date'] - df['signup_date']).dt.days

#Вычисляем и выводим давность последней поездки (сколько дней прошло).
df['Days_ago'] = (df.Today - df['Last_day']).dt.days

#Группировка по ID водителей.
group = df.groupby(['ID', 'signup_date', 'seniority', 'Last_day'])['rides'].size().reset_index()
#Названия новых колонок. Название 'ride_day_count' означает сколько дней были попытки таксовать. 
group.columns = ['ID', 'signup_date', 'seniority', 'Last_day', 'ride_days_count']
group['Days_ago'] = (pd.to_datetime(df.Today, format='%Y-%m-%d') - group['Last_day']).dt.days

#Далее необходимо написать функции присвоения рангов от 1 до 3.
#Водители с самыми недавними датами поездок получают ранг недавности 3, а поездившие совсем давно - получают ранг 1.
#Самые частые водители получают ранг частоты 3.
#Для этого будем использовать квантили. Каждый квинтиль содержит 33.3% от числа водителей.
quintiles = group[['Days_ago', 'ride_days_count']].quantile([.33, .66]).to_dict()

def RF_score(x, c):
    if x <= quintiles[c][.33]:
        return 1
    elif x <= quintiles[c][.66]:
        return 2
    else:
        return 3  

#Присваиваем ранг недавности 'R' (recency).
group['R'] = group['Days_ago'].apply(lambda x: RF_score(x, 'Days_ago')) 

#Присваиваем ранг частоты 'F' (frequcency).
group['F'] = group['ride_days_count'].apply(lambda x: RF_score(x, 'ride_days_count'))

group['RF-score'] = group['R'].map(str) + '-' + group['F'].map(str)

#Выводим на экран результаты RF-анализа
print(group)

#Строим таблицу pivot для наглядности N-day retention всех водителей.
#По оси Х будут дни после регистрации, по оси y - даты регистрации.

newgroup = df.groupby(['signup_date', 'seniority'])
cohort_data = newgroup['ID'].size().reset_index()

cohort_counts = cohort_data.pivot_table(index='signup_date', columns='seniority', values='ID')

base = cohort_counts[0]
retention = cohort_counts.divide(base, axis=0).round(3)

#Выводим N-day retention для всех водителей. Увеличьте размер head() при чтении файла чтобы увидеть все retention.
print(retention[3])
print(retention[7])
#print(retention[14])
#print(retention[30])
#print(retention[60])


plt.figure(figsize=(18,14))
plt.title('Drivers Active')
ax = sns.heatmap(data=cohort_counts, annot=True, vmin=0.0,cmap='Reds')
ax.set_yticklabels(cohort_counts.index)
fig=ax.get_figure()
fig.savefig("Retention Counts.png")

plt.show()