Add a stylistic rule: prefer ClipRSuperellipse for all corners

          ClipRSuperellipse(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Transform.scale(
              scale: 1 + (offsetRatio * 0.4),
              child: SizedBox(
                height: backgroundHeight,
                width: backgroundWidth,
                child: CommonThemeImage(
                  image: ThemeCommonImage.HeroBackground,
                  heightPercentage: heightPercentageStart,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          