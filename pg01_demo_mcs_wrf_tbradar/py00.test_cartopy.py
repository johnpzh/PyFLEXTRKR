import matplotlib.pyplot as plt
import cartopy.crs as ccrs
fig, ax = plt.subplots(1,1, subplot_kw={'projection': ccrs.PlateCarree()})
ax.coastlines()  # Triggers download
plt.savefig('test.png')